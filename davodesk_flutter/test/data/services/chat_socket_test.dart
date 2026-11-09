import 'package:davodesk_flutter/src/data/services/chat_socket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the socket.io socket waits to be told to connect', () {
    final socket = socketIoChatSocket(
      Uri.parse('http://127.0.0.1:9/chat'),
      's1',
    );
    expect(socket.active, isFalse);
    socket.disconnect();
  });
}
