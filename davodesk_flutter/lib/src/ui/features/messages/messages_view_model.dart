import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../domain/models.dart';
import '../../words.dart';

final _log = Logger('DavoDesk');

/// One conversation in the list; [answeredBy] is the person on the team who wrote
/// last, if one did.
class const MessageRow({
  required final String id,
  required final String subject,
  required final String status,
  required final String reference,
  final String line = '',
  final String day = '',
  final bool unread = false,
  final String? answeredBy,
}) {
  /// Creates a [MessageRow].
  this;
}

/// What Messages shows; a row nobody on the team answered last shows the brand's tile
/// ([logoUrl], else the initial of [brandName]), as the chat's header does (app
/// feedback spec §6).
class const MessagesState({
  final List<MessageRow> rows = const [],
  final bool loading = false,
  final bool failed = false,
  final String brandName = '',
  final String? logoUrl,
}) {
  /// Creates a [MessagesState].
  this;
}

/// Messages' state: the customer's tickets, last updated first.
class MessagesViewModel extends ChangeNotifier {
  /// Creates the view model over [_client], for the channel [_config].
  MessagesViewModel(this._client, this._config) {
    _changes.addListener(notifyListeners);
  }

  final DavoDeskClient _client;
  final ChannelConfig _config;
  late final _changes = Listenable.merge([_client.tickets, _client.unread]);
  bool _loading = true;
  bool _failed = false;

  /// What Messages shows now.
  MessagesState get state => MessagesState(
    rows: [
      for (final ticket
          in [..._client.tickets.value]..sort(
            (a, b) => (b.updatedAt ?? DateTime(0)).compareTo(
              a.updatedAt ?? DateTime(0),
            ),
          ))
        MessageRow(
          id: ticket.id,
          subject: ticket.subject,
          status: ticket.status,
          reference: referenceOf(ticket.id),
          line: lineOf(
            ticket.lastMessage,
            brand: _config.brandName,
            aiName: _config.aiAgentName,
          ),
          day: switch (ticket.updatedAt) {
            final at? => dayOf(at),
            null => '',
          },
          unread: _client.isUnread(ticket),
          answeredBy: switch (ticket.lastMessage) {
            LastMessage(senderType: .staff, :final senderDisplayName) =>
              speakerName(
                .staff,
                senderDisplayName,
                brand: _config.brandName,
                aiName: _config.aiAgentName,
              ),
            _ => null,
          },
        ),
    ],
    loading: _loading,
    failed: _failed,
    brandName: _config.brandName,
    logoUrl: _config.logoUrl,
  );

  /// Reads the tickets again.
  Future<void> load() async {
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      await _client.refreshTickets();
    } on Object catch (error) {
      _log.fine('Messages could not load: $error');
      _failed = true;
    }
    _loading = false;
    notifyListeners();
  }

  /// Marks the ticket [id] seen, as the customer opens it.
  Future<void> markSeen(String id) async {
    final ticket = _client.tickets.value.where((each) => each.id == id);
    if (ticket.isEmpty) return;
    await _client.markSeen(ticket.first);
  }

  @override
  void dispose() {
    _changes.removeListener(notifyListeners);
    super.dispose();
  }
}
