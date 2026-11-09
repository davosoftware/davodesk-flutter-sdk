import 'dart:async';
import 'dart:math';

import '../../domain/chat_events.dart';
import '../../domain/models.dart';
import '../services/chat_socket.dart';
import 'session_repository.dart';

/// The customer's live chat: the `/chat` socket, held as the integration guide's §4 says.
///
/// It acts on a refused connection only once socket.io has given up: a refused token
/// means a fresh session, a server hiccup the same one. The backoff resets when the
/// server admits the socket, never on connect.
class DavoDeskChat {
  /// Creates the chat at `apiUrl` for `session`'s customer.
  ///
  /// The private named parameters (Dart 3.12) are passed as `apiUrl:` and `session:`.
  DavoDeskChat({
    required this._apiUrl,
    required this._session,
    ChatSocketFactory? socketFactory,
    double Function()? random,
  }) : _socketFactory = socketFactory ?? socketIoChatSocket,
       _random = random ?? Random().nextDouble;

  final Uri _apiUrl;
  final DavoDeskSession _session;
  final ChatSocketFactory _socketFactory;
  final double Function() _random;
  final _events = StreamController<ChatEvent>.broadcast();

  ChatSocket? _socket;
  Timer? _timer;
  int _attempt = 0;
  bool _stopped = false;
  int _generation = 0;
  StreamSubscription<SessionState>? _waiting;

  // The server takes calls only once it has admitted the socket (its `session` event).
  Completer<ChatSocket?> _admitted = Completer();
  bool _isAdmitted = false;

  /// What the server says, and how the connection stands.
  Stream<ChatEvent> get events => _events.stream;

  /// Connects once the customer's session is open: now, or as soon as it opens.
  Future<void> connect() async {
    _stopped = false;
    final generation = _generation;
    _emit(const ConnectionEvent(.connecting));
    final state = await _session.ensure();
    if (generation != _generation) return;
    if (state case SessionReady(:final token)) {
      _open(token);
    } else {
      _whenReady(_open);
    }
  }

  /// A new conversation: the last one ended.
  Future<void> restart() {
    disconnect();
    return connect();
  }

  /// Stops for good; a call still waiting for the socket answers as not sent.
  void disconnect() {
    _stopped = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _waiting?.cancel();
    _waiting = null;
    _socket?.disconnect();
    _socket = null;
    _isAdmitted = false;
    if (!_admitted.isCompleted) _admitted.complete(null);
    _admitted = Completer();
  }

  /// Disconnects and closes [events].
  void dispose() {
    disconnect();
    _events.close();
  }

  /// Sends the customer's message.
  Future<ChatAck> send(String content) => _ack('message', {'content': content});

  /// Answers a choice the last reply offered.
  Future<ChatAck> choose(String key) => _ack('option:choose', {'key': key});

  /// Asks for a person on the team.
  Future<ChatAck> requestHandoff() => _ack('handoff:request', {});

  /// Answers DavoDesk AI's "Did this solve it?".
  Future<ChatAck> confirmResolution({required bool solved}) =>
      _ack('resolution:confirm', {'solved': solved});

  void _open(String token) {
    final socket = _socket = _socketFactory(_apiUrl.resolve('/chat'), token);
    _listen(socket);
    socket.connect();
  }

  void _whenReady(void Function(String token) open) {
    _waiting?.cancel();
    _waiting = _session.states.listen((state) {
      if (state is! SessionReady || _stopped) return;
      _waiting?.cancel();
      _waiting = null;
      open(state.token);
    });
  }

  void _reconnect({required bool fresh}) {
    if (_stopped) return;
    _emit(const ConnectionEvent(.reconnecting));
    _timer?.cancel();
    _timer = Timer(backoff(_attempt++, _random()), () async {
      _timer = null;
      final live = _socket;
      if (_stopped || live == null) return;
      if (!fresh) {
        live.connect();
        return;
      }
      void resume(String token) => live
        ..auth = {'token': token}
        ..connect();
      final state = await _session.renew();
      if (_stopped || !identical(live, _socket)) return;
      if (state case SessionReady(:final token)) {
        resume(token);
      } else {
        _whenReady(resume);
      }
    });
  }

  void _listen(ChatSocket live) => live
    ..on('session', (data) {
      _attempt = 0;
      _isAdmitted = true;
      if (!_admitted.isCompleted) _admitted.complete(live);
      _emit(SessionEvent(SessionSnapshot.fromJson(_map(data))));
      _emit(const ConnectionEvent(.live));
    })
    ..on('message', (data) {
      if (data case final Map<String, Object?> json) {
        _emit(MessageEvent(ChatMessage.fromJson(json)));
      }
    })
    ..on('handoff', (data) {
      final json = _map(data);
      _emit(
        HandoffEvent(
          ticketId: _string(json['ticket_id']) ?? '',
          resumed: json['resumed'] == true,
          reason: _string(json['reason']) ?? '',
        ),
      );
    })
    ..on(
      'human_joined',
      (data) => _emit(HumanJoinedEvent(_string(_map(data)['display_name']))),
    )
    ..on(
      'ended',
      (data) => _emit(EndedEvent(_string(_map(data)['reason']) ?? '')),
    )
    ..on(
      'resolved',
      (data) => _emit(ResolvedEvent(_string(_map(data)['ticket_id']) ?? '')),
    )
    ..on('chat_error', (data) {
      final json = _map(data);
      _emit(
        ChatErrorEvent(
          _string(json['code']) ?? '',
          retryAfter: switch (json['retry_after_seconds']) {
            final int seconds => seconds,
            _ => null,
          },
        ),
      );
    })
    ..on('connect_error', (error) {
      // While socket.io is still retrying on its own, racing it would only spend limits.
      if (live.active) return;
      _reconnect(fresh: _reasonOf(error) == 'UNAUTHENTICATED');
    })
    ..on('disconnect', (reason) {
      if (_stopped) return;
      if (_isAdmitted) {
        _isAdmitted = false;
        _admitted = Completer();
      }
      // A server cut is never retried by socket.io; anything else it retries itself.
      if (reason == 'io server disconnect') {
        _reconnect(fresh: true);
      } else {
        _emit(const ConnectionEvent(.reconnecting));
      }
    });

  /// A call waits until the server has admitted the socket (guide §4: one sent before
  /// is refused); with no connection coming, it is not sent.
  Future<ChatAck> _ack(String event, Map<String, Object?> payload) async {
    final live = _isAdmitted
        ? _socket
        : (_stopped ? null : await _admitted.future);
    if (live == null) return const ChatAck(ok: false);
    return ChatAck.fromJson(await live.emitWithAck(event, payload));
  }

  void _emit(ChatEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map<String, Object?> ? value : const {};

String? _string(Object? value) => value is String ? value : null;

/// What a refused connection says: socket.io hands the server's refusal over as
/// `{message}`.
String? _reasonOf(Object? error) => switch (error) {
  {'message': final String message} => message,
  final String message => message,
  _ => null,
};
