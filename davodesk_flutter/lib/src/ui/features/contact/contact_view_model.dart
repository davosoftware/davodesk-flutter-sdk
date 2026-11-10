import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../domain/models.dart';

final _log = Logger('DavoDesk');

/// The contact form's state: sending, the ticket it raised, or a refusal.
class ContactViewModel extends ChangeNotifier {
  /// Creates the view model over [_client].
  ContactViewModel(this._client);

  final DavoDeskClient _client;
  bool _sending = false;
  bool _failed = false;
  RaisedTicket? _raised;

  /// Whether a send is on its way.
  bool get sending => _sending;

  /// Whether the last send was refused.
  bool get failed => _failed;

  /// The ticket the form raised, once it has.
  RaisedTicket? get raised => _raised;

  /// Raises the ticket, once per tap however fast they come: one idempotency key each.
  ///
  /// The subject carries its key from [subjects] only while it is that subject's label.
  Future<RaisedTicket?> send({
    required String subject,
    required String message,
    String? extraLabel,
    String? extraValue,
    List<RequestSubject> subjects = const [],
  }) async {
    if (_sending) return null;
    _sending = true;
    _failed = false;
    notifyListeners();
    final typed = subject.trim();
    try {
      _raised = await _client.raiseTicket(
        subject: typed,
        message: message.trim(),
        extraLabel: extraLabel,
        extraValue: extraValue,
        subjectKey: subjects
            .where((each) => each.label == typed)
            .firstOrNull
            ?.key,
      );
    } on Object catch (error) {
      _log.fine('The contact form was refused: $error');
      _failed = true;
    }
    _sending = false;
    notifyListeners();
    return _raised;
  }
}
