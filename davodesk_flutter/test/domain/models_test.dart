import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

// Chat look spec: the API says which bot messages the AI wrote, and a channel's corners.
void main() {
  Map<String, Object?> bot([Map<String, Object?> extra = const {}]) => {
    'id': 'm1',
    'sender_type': 'bot',
    'content': 'Hi Chidi, how can we help today?',
    ...extra,
  };

  test('reads whether the AI wrote a message', () {
    expect(ChatMessage.fromJson(bot({'ai_written': true})).aiWritten, isTrue);
    expect(ChatMessage.fromJson(bot({'ai_written': false})).aiWritten, isFalse);
    // An API from before the field: no ✦ rather than a guess.
    expect(ChatMessage.fromJson(bot()).aiWritten, isNull);
  });

  test('reads the channel’s corners', () {
    ChannelLook look(Object? corners) =>
        ChannelLook.fromJson({'accent_color': '#0e9384', 'corners': ?corners});
    expect(look('square').corners, DavoDeskCorners.square);
    expect(look('rounded').corners, DavoDeskCorners.rounded);
    expect(look(null).corners, isNull);
    expect(look('round').corners, isNull);
  });
}
