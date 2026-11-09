import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../domain/conversation.dart';
import '../../../domain/models.dart';
import '../../core/scope.dart';
import '../../words.dart';

final _log = Logger('DavoDesk');

/// The conversation in progress, as Home's first card shows it; [ticketId] is null
/// for the live chat.
class const RecentCard({
  required final String subject,
  final String line = '',
  final bool unread = false,
  final String? ticketId,
}) {
  /// Creates a [RecentCard].
  this;
}

/// What Home shows.
class const HomeState({
  required final String brandName,
  final String? headerLogoUrl,
  final String? firstName,
  final bool showMessages = true,
  final bool showHelp = false,
  final bool showEmail = true,
  final List<HomeLink> links = const [],
  final RecentCard? recent,
  final bool failed = false,
}) {
  /// Creates a [HomeState].
  this;
}

const _open = {'open', 'in_progress', 'pending', 'escalated'};

/// A chat with the team (a person joined, or one is on the way) that hasn't ended, else
/// the open ticket updated last, else nothing: the web widget's `recentConversation`.
RecentCard? recentOf({
  required Conversation conversation,
  required List<TicketSummary> tickets,
  required bool Function(TicketSummary ticket) isUnread,
  required String brand,
  required String aiName,
}) {
  final withTheTeam =
      conversation.humanJoined || conversation.status == 'awaiting_human';
  if (withTheTeam && conversation.ended == null) {
    final last = conversation.messages.lastOrNull;
    final ticket = tickets
        .where((each) => each.id == conversation.ticketId)
        .firstOrNull;
    return RecentCard(
      subject: ticket?.subject ?? 'Your conversation',
      line: last == null
          ? ''
          : '${speakerName(last.senderType, last.senderDisplayName, brand: brand, aiName: aiName)}: '
                '${oneLine(last.content)}',
    );
  }
  final open = [
    for (final ticket in tickets)
      if (_open.contains(ticket.status)) ticket,
  ]..sort(_newestFirst);
  final ticket = open.firstOrNull;
  if (ticket == null) return null;
  return RecentCard(
    subject: ticket.subject,
    line: lineOf(ticket.lastMessage, brand: brand, aiName: aiName),
    unread: isUnread(ticket),
    ticketId: ticket.id,
  );
}

int _newestFirst(TicketSummary a, TicketSummary b) =>
    (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));

/// Home's state: it opens the customer's session, the chat and their tickets, and
/// checks for a help centre.
class HomeViewModel extends ChangeNotifier {
  /// Creates Home's view model over [_client], for the channel [_config].
  HomeViewModel(this._client, this._config) {
    _changes.addListener(notifyListeners);
  }

  final DavoDeskClient _client;
  final ChannelConfig _config;
  late final _changes = Listenable.merge([
    _client.conversation,
    _client.tickets,
    _client.unread,
  ]);
  bool _hasHelp = false;
  bool _failed = false;

  /// What Home shows now.
  HomeState get state => HomeState(
    brandName: _config.brandName,
    headerLogoUrl: _config.headerLogoUrl,
    firstName: firstNameOf(_client.customerName),
    showMessages: !_config.answersOnly,
    showHelp: _hasHelp,
    showEmail: !_config.answersOnly,
    links: [
      for (final link in _config.appearance?.homeLinks ?? const <HomeLink>[])
        if (isWebLink(link.url)) link,
    ],
    recent: recentOf(
      conversation: _client.conversation.value,
      tickets: _client.tickets.value,
      isUnread: _client.isUnread,
      brand: _config.brandName,
      aiName: _config.aiAgentName,
    ),
    failed: _failed,
  );

  /// Opens the session, the chat and the tickets, and checks for articles.
  Future<void> load() async {
    _failed = false;
    notifyListeners();
    try {
      await _client.start();
      _hasHelp = await _client.hasHelpCentre();
    } on Object catch (error) {
      _log.fine('Home could not load: $error');
      _failed = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _changes.removeListener(notifyListeners);
    super.dispose();
  }
}
