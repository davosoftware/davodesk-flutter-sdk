import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../domain/models.dart';
import '../../words.dart';
import '../conversation/conversation_view_model.dart';

final _log = Logger('DavoDesk');

/// What a ticket shows.
class const TicketState({
  final String subject = '',
  final String status = 'open',
  final String reference = '',
  final List<BubbleItem> items = const [],
  final bool askRating = false,
  final bool reopenable = false,
  final bool loading = true,
  final bool failed = false,
}) {
  /// Creates a [TicketState].
  this;

  /// Whether the ticket takes no more messages.
  bool get closed => status == 'closed';

  /// Whether the team still works on it, so the conversation can go on.
  bool get open => status != 'resolved' && status != 'closed';
}

/// A ticket's state: its conversation, the rating if the team asked, Reopen if allowed.
class TicketViewModel extends ChangeNotifier {
  /// Creates the view model for the ticket [_id] over [_client].
  TicketViewModel(this._client, this._config, this._id);

  final DavoDeskClient _client;
  final ChannelConfig _config;
  final String _id;
  CustomerTicket? _ticket;
  bool _failed = false;

  /// What the ticket shows now.
  TicketState get state {
    final ticket = _ticket;
    if (ticket == null) return TicketState(failed: _failed, loading: !_failed);
    return TicketState(
      subject: ticket.subject,
      status: ticket.status,
      reference: referenceOf(ticket.id),
      items: [
        for (final message in ticket.messages)
          bubbleOf(message, brand: _config.brandName, ai: _config.aiAgentName),
      ],
      askRating: ticket.summary.satisfaction?.awaitingRating ?? false,
      reopenable: ticket.reopenable,
      loading: false,
    );
  }

  /// Reads the ticket (the one it was merged into, when it was), and marks it seen.
  Future<void> load() async {
    _failed = false;
    notifyListeners();
    await _settle(() => _client.openTicket(_id));
  }

  /// Rates the help `good` or `bad`, with an optional [comment].
  Future<void> rate(String rating, String? comment) => _settle(
    () => _client.rate(_ticket?.id ?? _id, rating: rating, comment: comment),
  );

  /// Reopens the ticket.
  Future<void> reopen() => _settle(() => _client.reopen(_ticket?.id ?? _id));

  Future<void> _settle(Future<CustomerTicket> Function() call) async {
    try {
      _ticket = await call();
    } on Object catch (error) {
      _log.fine('The ticket could not be read: $error');
      _failed = true;
    }
    notifyListeners();
  }
}
