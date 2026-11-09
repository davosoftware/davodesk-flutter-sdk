import 'package:socket_io_client/socket_io_client.dart' as socket_io;

/// The part of a Socket.IO client the chat uses, so tests can stand in a fake.
abstract interface class ChatSocket {
  /// Whether socket.io still reconnects by itself: false once the server refused the
  /// connection or the socket was told to stop.
  bool get active;

  /// What the next connect hands the server: `{token}`.
  set auth(Map<String, Object?> value);

  /// Calls [handler] with what the server sends as [event].
  void on(String event, void Function(Object? data) handler);

  /// Connects, or connects again after socket.io gave up.
  void connect();

  /// Disconnects for good.
  void disconnect();

  /// Sends [event] with [payload] and completes with the server's answer.
  Future<Object?> emitWithAck(String event, Object? payload);
}

/// Makes the `/chat` socket at a URL, to connect with a session token.
typedef ChatSocketFactory = ChatSocket Function(Uri url, String token);

/// socket.io's own client: websocket only, its own connection, and connecting only when
/// told to, so every handler is in place first.
ChatSocket socketIoChatSocket(Uri url, String token) => _SocketIo(
  socket_io.io(
    url.toString(),
    socket_io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableForceNew()
        .setAuth({'token': token})
        .build(),
  ),
);

final class _SocketIo(final socket_io.Socket _socket) implements ChatSocket {
  @override
  bool get active => _socket.active;

  @override
  set auth(Map<String, Object?> value) => _socket.auth = value;

  @override
  void on(String event, void Function(Object? data) handler) =>
      _socket.on(event, handler);

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.dispose();

  @override
  Future<Object?> emitWithAck(String event, Object? payload) =>
      _socket.emitWithAckAsync(event, payload);
}
