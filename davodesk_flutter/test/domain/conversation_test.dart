import 'package:davodesk_flutter/davodesk_flutter.dart';
import 'package:davodesk_flutter/src/domain/chat_events.dart';
import 'package:davodesk_flutter/src/domain/conversation.dart' show reduce;
import 'package:flutter_test/flutter_test.dart';

var _seq = 0;

ChatMessage message({
  SenderType sender = .bot,
  String content = 'Hello',
  List<ChatOption> options = const [],
}) => ChatMessage(
  id: 'm${++_seq}',
  senderType: sender,
  content: content,
  options: options,
);

Conversation run(List<ConversationEvent> events) =>
    events.fold(const Conversation(), reduce);

void main() {
  test("takes the snapshot's status, ticket and history", () {
    final first = message(content: 'Hi');
    final state = run([
      SessionEvent(
        SessionSnapshot(
          id: 'cs1',
          status: 'live',
          ticketId: 't1',
          messages: [first],
        ),
      ),
    ]);
    expect(state.status, 'live');
    expect(state.ticketId, 't1');
    expect(state.messages, [first]);
  });

  test('a replay keeps the snapshot status and replaces what came before', () {
    final asked = message(options: const [ChatOption('t1', 'Billing')]);
    final state = run([
      MessageEvent(message(content: 'From before')),
      const EndedEvent('helped'),
      SessionEvent(
        SessionSnapshot(
          id: 'cs1',
          status: 'awaiting_human',
          ticketId: 't1',
          messages: [asked],
        ),
      ),
    ]);
    expect(state.status, 'awaiting_human');
    expect(state.messages, [asked]);
    expect(state.options.map((option) => option.key), ['t1']);
    expect(state.ended, isNull);
  });

  test('options clear when the customer writes', () {
    final asked = run([
      MessageEvent(message(options: const [ChatOption('t1', 'Billing')])),
    ]);
    expect(asked.options.map((option) => option.key), ['t1']);
    final answered = reduce(
      asked,
      MessageEvent(message(sender: .endUser, content: 'Billing')),
    );
    expect(answered.options, isEmpty);
  });

  test('a message arriving twice shows once', () {
    final one = message();
    expect(run([MessageEvent(one), MessageEvent(one)]).messages, [one]);
  });

  test('a handoff waits for a person, keeping its ticket', () {
    final state = run([
      const HandoffEvent(
        ticketId: 't9',
        resumed: false,
        reason: 'customer_requested',
      ),
    ]);
    expect(state.status, 'awaiting_human');
    expect(state.ticketId, 't9');
  });

  test(
    'human_joined sets live and the name; an unnamed person still joined',
    () {
      expect(const Conversation().humanJoined, isFalse);
      final named = run([const HumanJoinedEvent('Mara')]);
      expect(named.status, 'live');
      expect(named.humanJoined, isTrue);
      expect(named.agentName, 'Mara');
      final unnamed = run([const HumanJoinedEvent(null)]);
      expect(unnamed.humanJoined, isTrue);
      expect(unnamed.agentName, isNull);
    },
  );

  test('ended ticket_closed closes', () {
    final state = run([
      MessageEvent(message(options: const [ChatOption('t1', 'Billing')])),
      const EndedEvent('ticket_closed'),
    ]);
    expect(state.status, 'closed');
    expect(state.ended, 'ticket_closed');
    expect(state.options, isEmpty);
  });

  test('a resolution closes, recording its ticket', () {
    final state = run([const ResolvedEvent('t3')]);
    expect(state.status, 'closed');
    expect(state.ticketId, 't3');
  });

  test('RATE_LIMITED sets limitedFor until the customer writes', () {
    final limited = run([const ChatErrorEvent('RATE_LIMITED', retryAfter: 20)]);
    expect(limited.limitedFor, const Duration(seconds: 20));
    expect(
      run([const ChatErrorEvent('RATE_LIMITED')]).limitedFor,
      const Duration(minutes: 1),
    );
    expect(run([const ChatErrorEvent('CONNECTION_FAILED')]).limitedFor, isNull);
    final cleared = reduce(limited, MessageEvent(message(sender: .endUser)));
    expect(cleared.limitedFor, isNull);
  });

  test('follows the connection', () {
    expect(const Conversation().connection, ChatConnection.connecting);
    expect(
      run([const ConnectionEvent(.reconnecting)]).connection,
      ChatConnection.reconnecting,
    );
  });

  test('reset starts anew but keeps the connection', () {
    final state = run([
      const ConnectionEvent(.live),
      MessageEvent(message()),
      const HumanJoinedEvent('Mara'),
      const ResetEvent(),
    ]);
    expect(state.connection, ChatConnection.live);
    expect(state.status, 'none');
    expect(state.messages, isEmpty);
    expect(state.humanJoined, isFalse);
  });
}
