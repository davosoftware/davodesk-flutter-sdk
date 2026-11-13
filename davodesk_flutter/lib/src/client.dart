import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'data/repositories/chat_repository.dart';
import 'data/repositories/seen_repository.dart';
import 'data/repositories/seen_repository.dart' as seen show isUnread;
import 'data/repositories/session_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/chat_socket.dart';
import 'domain/chat_events.dart';
import 'domain/conversation.dart';
import 'domain/models.dart';

final _log = Logger('DavoDesk');

/// No session could open, so the customer's calls can't be made now; it retries by
/// itself. [state] says why.
class DavoDeskUnavailable implements Exception {
  /// Creates the refusal.
  const DavoDeskUnavailable(this.state);

  /// Where the session stands.
  final SessionState state;

  @override
  String toString() => 'DavoDeskUnavailable($state)';
}

/// DavoDesk for one customer on one app channel: what the support screens use, and what
/// an app that draws its own screens builds on.
///
/// Create it once the app's binding is ready; it opens a fresh session when the app
/// comes back to the foreground. Call [dispose] when done with it.
class DavoDeskClient {
  /// Creates the client for `channelId`, whose customer `identityToken` names: a function
  /// that asks the app's backend for a fresh identity token, called on each session open.
  DavoDeskClient({
    required String channelId,
    required Future<String?> Function() identityToken,
    Uri? apiUrl,
    http.Client? httpClient,
    ChatSocketFactory? socketFactory,
  }) : _channelId = channelId,
       _api = DavoDeskApi(
         baseUrl: apiUrl ?? Uri.parse('https://api.davodesk.com'),
         client: httpClient,
       ) {
    _session = DavoDeskSession(
      api: _api,
      channelId: channelId,
      identityToken: identityToken,
    );
    _chat = DavoDeskChat(
      apiUrl: _api.baseUrl,
      session: _session,
      socketFactory: socketFactory,
    );
    _chatEvents = _chat.events.listen((event) {
      _conversation.value = reduce(_conversation.value, event);
      // An ended chat answers nothing more: the next message needs a new one. A closed
      // ticket waits for the customer's Start a new conversation.
      if (event case EndedEvent(reason: 'helped' || 'idle')) {
        unawaited(_chat.restart());
      }
      // A ticket opened or closed: Messages, Home's card and the badge read it.
      if (event is HandoffEvent ||
          event is EndedEvent ||
          event is ResolvedEvent) {
        unawaited(refreshTickets().catchError((Object _) {}));
      }
    });
    _lifecycle = AppLifecycleListener(
      binding: WidgetsFlutterBinding.ensureInitialized(),
      onResume: () => unawaited(resumed()),
    );
  }

  final String _channelId;
  final DavoDeskApi _api;
  late final DavoDeskSession _session;
  late final DavoDeskChat _chat;
  late final StreamSubscription<ChatEvent> _chatEvents;
  late final AppLifecycleListener _lifecycle;
  final _seen = SeenStore();
  final _random = Random.secure();

  final _conversation = ValueNotifier(const Conversation());
  final _tickets = ValueNotifier<List<TicketSummary>>(const []);
  final _unread = ValueNotifier(0);

  Future<ChannelConfig>? _config;
  ChannelConfig? _lastConfig;
  bool _readingConfig = false;
  bool? _hasHelpCentre;
  bool _connected = false;

  /// The live conversation, as the screens draw it.
  ValueListenable<Conversation> get conversation => _conversation;

  /// The customer's tickets, newest first, as of the last [refreshTickets].
  ValueListenable<List<TicketSummary>> get tickets => _tickets;

  /// How many tickets changed since the customer last looked: for a badge.
  ValueListenable<int> get unread => _unread;

  /// The customer's name, once their session is open.
  String? get customerName => switch (_session.state) {
    SessionReady(:final name) => name,
    _ => null,
  };

  /// Every change in the customer's session, such as a refused identity token.
  Stream<SessionState> get sessionChanges => _session.states;

  /// The channel's public settings, read once until [forgetConfig].
  Future<ChannelConfig> config() => _config ??= _readConfig();

  /// Drops the settings read, so the next [config] reads them again: a look saved in
  /// DavoDesk shows the next time support opens. A read on its way is kept.
  void forgetConfig() {
    if (!_readingConfig) _config = null;
  }

  /// The settings read again as support opens. When some were read before and this read
  /// fails or takes longer than [wait], those instead, so support still opens at once;
  /// the read carries on for the next time.
  Future<ChannelConfig> configForOpening({
    Duration wait = const Duration(seconds: 2),
  }) {
    forgetConfig();
    final reading = config();
    final last = _lastConfig;
    if (last == null) return reading;
    return reading
        .timeout(wait, onTimeout: () => last)
        .catchError((Object _) => last);
  }

  /// Opens the customer's session and the live chat, and reads their tickets. A brand
  /// that only answers from its articles has no chat and no tickets.
  Future<void> start() async {
    final config = await this.config();
    if (config.answersOnly) {
      await _ready();
      return;
    }
    if (!_connected) {
      _connected = true;
      unawaited(_chat.connect());
    }
    await refreshTickets();
  }

  /// Opens a fresh session and reads the tickets again: the app came back to the
  /// foreground (the integration guide, §10).
  Future<void> resumed() async {
    if (_session.state is SessionIdle) return;
    await _session.renew();
    try {
      await refreshTickets();
    } on Object catch (error) {
      _log.fine('The tickets could not be read on resume: $error');
    }
  }

  /// Reads the customer's tickets again, and the unread count with them.
  Future<void> refreshTickets() async {
    if ((await config()).answersOnly) return;
    final list = await _authed(_api.tickets);
    await _loadSeen();
    _tickets.value = List.unmodifiable(list);
    _recount();
  }

  /// Notes that the customer saw [ticket] as it stands.
  Future<void> markSeen(TicketSummary ticket) async {
    await _loadSeen();
    if (ticket.updatedAt case final at?) await _seen.mark(ticket.id, at);
    _recount();
  }

  /// Whether [ticket] changed since the customer last looked, as [unread] counts it.
  bool isUnread(TicketSummary ticket) => seen.isUnread(ticket, _seen.markers);

  /// Sends the customer's message in the conversation.
  Future<ChatAck> send(String text) => _chat.send(text);

  /// Answers a choice the last reply offered.
  Future<ChatAck> choose(String key) => _chat.choose(key);

  /// Asks for a person on the team.
  Future<ChatAck> talkToPerson() => _chat.requestHandoff();

  /// Answers DavoDesk AI's "Did this solve it?".
  Future<ChatAck> confirm({required bool solved}) =>
      _chat.confirmResolution(solved: solved);

  /// Starts a new conversation after the last one ended.
  Future<void> startNew() async {
    _conversation.value = reduce(_conversation.value, const ResetEvent());
    _connected = true;
    await _chat.restart();
  }

  /// One of the customer's tickets, with its messages: the one it was merged into, when
  /// it was. Both count as seen.
  Future<CustomerTicket> openTicket(String id) async {
    var ticket = await _authed((token) => _api.ticket(token, id));
    if (ticket.mergedInto case final into?) {
      ticket = await _authed((token) => _api.ticket(token, into));
    }
    await _loadSeen();
    if (ticket.summary.updatedAt case final at?) {
      await _seen.mark(id, at);
      await _seen.mark(ticket.id, at);
    }
    _recount();
    return ticket;
  }

  /// Rates a ticket `good` or `bad`, with an optional [comment].
  Future<CustomerTicket> rate(
    String ticketId, {
    required String rating,
    String? comment,
  }) => _authed(
    (token) => _api.rate(token, ticketId, rating: rating, comment: comment),
  );

  /// Reopens a solved ticket.
  Future<CustomerTicket> reopen(String ticketId) =>
      _authed((token) => _api.reopen(token, ticketId));

  /// Raises a ticket from the contact form, or adds to the customer's open one.
  ///
  /// A filled-in extra field goes first in the message, as "[extraLabel]: [extraValue]".
  /// [subjectKey] is the key of one of [ChannelConfig.requestSubjects], sent while
  /// [subject] is its label. Each call is one request with its own idempotency key, kept
  /// for the retries when an answer is lost in transit (the integration guide, §8).
  Future<RaisedTicket> raiseTicket({
    required String subject,
    required String message,
    String? extraLabel,
    String? extraValue,
    String? subjectKey,
  }) async {
    final extra = extraValue?.trim() ?? '';
    final label = extraLabel?.trim() ?? '';
    final body = switch ((label, extra)) {
      (_, '') => message,
      ('', _) => '$extra\n\n$message',
      _ => '$label: $extra\n\n$message',
    };
    final key = _uuid();
    final raised = await _authed(
      (token) => _inTransit(
        () => _api.raiseTicket(
          token,
          subject: subject,
          message: body,
          idempotencyKey: key,
          subjectKey: subjectKey,
        ),
      ),
    );
    unawaited(refreshTickets().catchError((Object _) {}));
    return raised;
  }

  /// Attaches [files] to a ticket.
  Future<void> attach(String ticketId, List<UploadFile> files) =>
      _authed((token) => _api.attach(token, ticketId, files));

  /// Whether the brand's help centre has any published article, read once.
  Future<bool> hasHelpCentre() async =>
      _hasHelpCentre ??= (await articles(limit: 1)).total > 0;

  /// Searches the help centre.
  Future<List<ArticleHit>> search(String query) async =>
      _api.search(await _brandId(), query);

  /// The help centre's published articles, all or one collection's.
  Future<ArticlePage> articles({String? categoryId, int? limit}) async =>
      _api.articles(await _brandId(), categoryId: categoryId, limit: limit);

  /// One published article, or null when it no longer exists.
  Future<PublicArticle?> article(String id) async =>
      _api.article(await _brandId(), id);

  /// The help centre's collections.
  Future<List<CategoryNode>> categories() async =>
      _api.categories(await _brandId());

  /// Says whether an article helped.
  Future<void> vote(String articleId, {required bool helpful}) =>
      _authed((token) => _api.vote(token, articleId, helpful: helpful));

  /// Ends the session and forgets this customer on the device: call it when the app's
  /// user signs out. The next call opens a session for whoever signs in.
  Future<void> logout() async {
    _chat.disconnect();
    _connected = false;
    await _session.logout();
    await _seen.clear();
    _tickets.value = const [];
    _unread.value = 0;
    _conversation.value = const Conversation();
    _hasHelpCentre = null;
  }

  /// Stops everything the client runs.
  void dispose() {
    _lifecycle.dispose();
    unawaited(_chatEvents.cancel());
    _chat.dispose();
    _session.dispose();
    _conversation.dispose();
    _tickets.dispose();
    _unread.dispose();
  }

  Future<ChannelConfig> _readConfig() async {
    _readingConfig = true;
    try {
      return _lastConfig = await _api.config(_channelId);
    } on Object {
      _config = null;
      rethrow;
    } finally {
      _readingConfig = false;
    }
  }

  Future<SessionReady> _ready() async => switch (await _session.ensure()) {
    final SessionReady ready => ready,
    final state => throw DavoDeskUnavailable(state),
  };

  Future<String> _brandId() async => (await _ready()).brandId;

  /// Calls with the session's token; a `401` means the server ended the session early
  /// (the integration guide, §2), so it opens a fresh one and tries once more.
  Future<T> _authed<T>(Future<T> Function(String token) call) async {
    final ready = await _ready();
    try {
      return await call(ready.token);
    } on DavoDeskApiError catch (error) {
      if (error.status != 401) rethrow;
      return switch (await _session.renew()) {
        SessionReady(:final token) => call(token),
        final state => throw DavoDeskUnavailable(state),
      };
    }
  }

  /// Tries [request] up to three times while no answer comes back at all.
  Future<T> _inTransit<T>(Future<T> Function() request) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request();
      } on DavoDeskApiError {
        rethrow;
      } on Object catch (error) {
        if (attempt == 2) rethrow;
        _log.fine('No answer, trying again: $error');
        await Future<void>.delayed(backoff(attempt, _random.nextDouble()));
      }
    }
  }

  Future<void> _loadSeen() => _seen.load(_channelId, _session.subject);

  void _recount() => _unread.value = unreadCount(_tickets.value, _seen.markers);

  String _uuid() {
    final bytes = [for (var i = 0; i < 16; i++) _random.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ];
    return [
      hex.sublist(0, 4).join(),
      hex.sublist(4, 6).join(),
      hex.sublist(6, 8).join(),
      hex.sublist(8, 10).join(),
      hex.sublist(10).join(),
    ].join('-');
  }
}
