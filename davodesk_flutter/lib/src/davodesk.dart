import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'client.dart';
import 'data/repositories/session_repository.dart';
import 'domain/models.dart' show ChannelConfig;
import 'ui/core/scope.dart';
import 'ui/core/support_shell.dart';
import 'ui/features/contact/contact_page.dart';
import 'ui/features/conversation/conversation_page.dart';
import 'ui/features/help/article_page.dart';
import 'ui/features/help/collection_page.dart';
import 'ui/features/help/help_page.dart';
import 'ui/features/home/home_page.dart';
import 'ui/features/messages/messages_page.dart';
import 'ui/features/ticket/ticket_page.dart';
import 'ui/theme.dart';
import 'ui/words.dart';

/// A support page [DavoDesk.show] can open.
enum DavoDeskPage {
  /// Home: the greeting, Chat with us, Help and Send us a message.
  home,

  /// The customer's chats, with Start a new chat.
  chats,

  /// The help centre.
  help,

  /// The contact form, "Send us a message".
  contact,
}

/// Something the app may want to know about support.
sealed class DavoDeskEvent {
  /// Creates an event.
  const DavoDeskEvent();
}

/// Support opened on the app's navigator.
final class const DavoDeskOpened() extends DavoDeskEvent {
  /// Creates the event.
  this;
}

/// The last support page closed.
final class const DavoDeskClosed() extends DavoDeskEvent {
  /// Creates the event.
  this;
}

/// How many conversations changed since the customer last looked: [count].
final class const DavoDeskUnread(final int count) extends DavoDeskEvent {
  /// Creates the event.
  this;
}

/// A request reached the team as the ticket [id], known to the customer as
/// [reference].
final class const DavoDeskTicketRaised(final String id, final String reference)
    extends DavoDeskEvent {
  /// Creates the event.
  this;
}

/// Something the app's developer should know: [code], such as `TOKEN_FAILED` (the
/// identity function gave no usable token), and a [message].
final class const DavoDeskError(final String code, final String message)
    extends DavoDeskEvent {
  /// Creates the event.
  this;
}

/// DavoDesk support inside the app: initialize it once the user signs in, then show
/// its pages, ask a question, open a ticket, read the unread count, and log out.
abstract final class DavoDesk {
  static _Support? _current;

  static _Support get _support =>
      _current ?? (throw StateError('Call DavoDesk.initialize first.'));

  /// Sets support up for the channel [channelId], whose customer [identityToken]
  /// names: a function that asks the app's backend for a fresh identity token.
  ///
  /// [theme] gives the screens an accent, light or dark, or a font; [contactForm] sets
  /// the contact form's note and extra field. Calling it again starts over.
  static Future<void> initialize({
    required String channelId,
    required Future<String?> Function() identityToken,
    String apiUrl = 'https://api.davodesk.com',
    DavoDeskTheme? theme,
    DavoDeskContactForm? contactForm,
  }) {
    WidgetsFlutterBinding.ensureInitialized();
    return initializeWith(
      DavoDeskClient(
        channelId: channelId,
        identityToken: identityToken,
        apiUrl: Uri.parse(apiUrl),
      ),
      theme: theme,
      contactForm: contactForm,
    );
  }

  /// Sets support up over [client]; for tests.
  @visibleForTesting
  static Future<void> initializeWith(
    DavoDeskClient client, {
    DavoDeskTheme? theme,
    DavoDeskContactForm? contactForm,
  }) async {
    await reset();
    final support = _current = _Support(client, theme, contactForm);
    // The unread badge needs the tickets before support is first opened.
    await support.client.refreshTickets().catchError((Object _) {});
  }

  /// Stops support and forgets it; for tests.
  @visibleForTesting
  static Future<void> reset() async {
    final support = _current;
    _current = null;
    support?.dispose();
  }

  /// Opens [page] (Home by default) over the app.
  static Future<void> show(
    BuildContext context, {
    DavoDeskPage page = DavoDeskPage.home,
  }) => _support.open(context, switch (page) {
    .home => const HomePage(),
    .chats => const MessagesPage(),
    .help => const HelpPage(),
    .contact => const ContactPage(),
  });

  /// Opens the conversation and asks [text] in it; a brand that only answers from its
  /// articles opens Help instead.
  static Future<void> ask(BuildContext context, String text) async {
    final support = _support;
    final config = await support.config();
    if (config == null || !context.mounted) return;
    if (config.answersOnly) {
      support._push(context, config, const HelpPage());
      return;
    }
    unawaited(support.client.send(text).then((_) {}, onError: (Object _) {}));
    support._push(context, config, const ConversationPage());
  }

  /// Opens one of the customer's tickets, such as from a push notification.
  static Future<void> openTicket(BuildContext context, String ticketId) =>
      _support.open(context, TicketPage(id: ticketId));

  /// How many conversations changed since the customer last looked: for a badge.
  static ValueListenable<int> get unread => _support.client.unread;

  /// Support's events: opened, closed, unread, a raised ticket, and errors.
  static Stream<DavoDeskEvent> get events => _support.events.stream;

  /// Closes support and forgets the customer: call it when the app's user signs out.
  static Future<void> logout() => _support.logout();
}

class _Support {
  _Support(this.client, this.theme, this.contactForm) {
    client.unread.addListener(_onUnread);
    client.conversation.addListener(_onConversation);
    _sessionChanges = client.sessionChanges.listen(_onSession);
  }

  final DavoDeskClient client;
  final DavoDeskTheme? theme;
  final DavoDeskContactForm? contactForm;
  final events = StreamController<DavoDeskEvent>.broadcast();
  final _routes = <Route<void>>[];
  late final StreamSubscription<SessionState> _sessionChanges;
  String? _announced;
  bool _toldTokenFailed = false;

  /// The channel's settings, read again for each opening: a look saved in DavoDesk shows
  /// the next time support opens.
  Future<ChannelConfig?> config() async {
    try {
      return await client.configForOpening();
    } on Object catch (error) {
      _emit(DavoDeskError('CHANNEL_UNAVAILABLE', '$error'));
      return null;
    }
  }

  Future<void> open(BuildContext context, Widget page) async {
    final config = await this.config();
    if (config == null || !context.mounted) return;
    _push(context, config, page);
  }

  void _push(BuildContext context, ChannelConfig config, Widget page) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SupportScope(
        client: client,
        config: config,
        contactForm: contactForm,
        go: (from, place) => _push(from, config, _pageOf(place)),
        onRaised: (raised) => _announce(raised.ticket.id),
        child: Builder(
          builder: (inside) => SupportShell(
            colors: SupportColors.resolve(inside, config: config, theme: theme),
            child: page,
          ),
        ),
      ),
    );
    if (_routes.isEmpty) _emit(const DavoDeskOpened());
    _routes.add(route);
    unawaited(
      Navigator.of(context).push(route).whenComplete(() => _gone(route)),
    );
  }

  static Widget _pageOf(SupportPlace place) => switch (place) {
    MessagesPlace() => const MessagesPage(),
    HelpPlace() => const HelpPage(),
    ContactPlace() => const ContactPage(),
    ConversationPlace(:final fresh) => ConversationPage(fresh: fresh),
    TicketPlace(:final id) => TicketPage(id: id),
    CollectionPlace(:final id, :final name) => CollectionPage(
      id: id,
      name: name,
    ),
    ArticlePlace(:final id) => ArticlePage(id: id),
  };

  void _gone(Route<void> route) {
    if (!_routes.remove(route)) return;
    if (_routes.isEmpty) _emit(const DavoDeskClosed());
  }

  Future<void> logout() async {
    final routes = [..._routes];
    _routes.clear();
    for (final route in routes.reversed) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    if (routes.isNotEmpty) _emit(const DavoDeskClosed());
    _announced = null;
    await client.logout();
  }

  void _onUnread() => _emit(DavoDeskUnread(client.unread.value));

  void _onConversation() {
    if (client.conversation.value.ticketId case final id?) _announce(id);
  }

  void _announce(String ticketId) {
    if (ticketId == _announced) return;
    _announced = ticketId;
    _emit(DavoDeskTicketRaised(ticketId, referenceOf(ticketId)));
  }

  /// A refused identity token is told once per run of refusals, as the web does.
  void _onSession(SessionState state) {
    final refused = state is SessionUnavailable && state.code == 'TOKEN_FAILED';
    if (refused && !_toldTokenFailed) {
      _emit(
        const DavoDeskError(
          'TOKEN_FAILED',
          'The identity function gave no usable identity token.',
        ),
      );
    }
    if (refused || state is SessionReady) _toldTokenFailed = refused;
  }

  void _emit(DavoDeskEvent event) {
    if (!events.isClosed) events.add(event);
  }

  void dispose() {
    client.unread.removeListener(_onUnread);
    client.conversation.removeListener(_onConversation);
    client.dispose();
    unawaited(_sessionChanges.cancel());
    unawaited(events.close());
  }
}
