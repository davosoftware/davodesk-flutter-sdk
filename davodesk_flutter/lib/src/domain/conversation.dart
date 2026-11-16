import 'chat_events.dart';
import 'models.dart';

const _keep = Object();

/// The chat as the screens draw it, moved on by each [ConversationEvent].
///
/// - [status] is `none` until the server's snapshot, then the chat's: `answers`, `bot`,
///   `intake`, `awaiting_human`, `live` or `closed`.
/// - [messages] are in order, each once.
/// - [options] are the choices the last reply offered, gone once the customer writes.
/// - [humanJoined] says a person on the team joined, and [agentName] is their public
///   name: null when they have none, so the screens show the brand's team.
/// - [ended] is why the chat ended, such as `ticket_closed`; null while it runs.
/// - [limitedFor] is how long the server asked the customer to wait before writing
///   again (a minute when it didn't say); null when they may write.
/// - [pending] are the customer's messages on their way, oldest first.
class const Conversation({
  final String status = 'none',
  final String? ticketId,
  final List<ChatMessage> messages = const [],
  final List<ChatOption> options = const [],
  final bool humanJoined = false,
  final String? agentName,
  final String? ended,
  final ChatConnection connection = .connecting,
  final Duration? limitedFor,
  final List<PendingMessage> pending = const [],
}) {
  /// Creates a conversation; with no arguments, the one before the chat connects.
  this;

  Conversation _with({
    String? status,
    Object? ticketId = _keep,
    List<ChatMessage>? messages,
    List<ChatOption>? options,
    bool? humanJoined,
    Object? agentName = _keep,
    Object? ended = _keep,
    ChatConnection? connection,
    Object? limitedFor = _keep,
    List<PendingMessage>? pending,
  }) => Conversation(
    status: status ?? this.status,
    ticketId: identical(ticketId, _keep) ? this.ticketId : ticketId as String?,
    messages: messages ?? this.messages,
    options: options ?? this.options,
    humanJoined: humanJoined ?? this.humanJoined,
    agentName: identical(agentName, _keep)
        ? this.agentName
        : agentName as String?,
    ended: identical(ended, _keep) ? this.ended : ended as String?,
    connection: connection ?? this.connection,
    limitedFor: identical(limitedFor, _keep)
        ? this.limitedFor
        : limitedFor as Duration?,
    pending: pending ?? this.pending,
  );
}

/// A message the customer sent that has not come back from the server yet (app
/// feedback spec §1); [failed] once it was refused: "Not sent", with Retry.
class const PendingMessage(
  final String clientId,
  final String content, {
  final bool failed = false,
}) {
  /// Creates a [PendingMessage].
  this;
}

/// Moves [state] on by [event]: the web widget's `reduce`, without the visitor's email
/// steps, which an app's signed-in customers never meet.
Conversation reduce(Conversation state, ConversationEvent event) =>
    switch (event) {
      // A replay keeps the snapshot's status and replaces what came before.
      SessionEvent(:final snapshot) => _replayed(state, snapshot),
      MessageEvent(:final message) => _withMessage(state, message),
      HandoffEvent(:final ticketId) => state._with(
        status: 'awaiting_human',
        ticketId: ticketId,
      ),
      HumanJoinedEvent(:final displayName) => state._with(
        status: 'live',
        humanJoined: true,
        agentName: displayName,
      ),
      EndedEvent(:final reason) => state._with(
        status: 'closed',
        ended: reason,
        options: const [],
      ),
      ResolvedEvent(:final ticketId) => state._with(
        status: 'closed',
        ticketId: ticketId,
        options: const [],
      ),
      ChatErrorEvent(code: 'RATE_LIMITED', :final retryAfter) => state._with(
        limitedFor: Duration(seconds: retryAfter ?? 60),
      ),
      ChatErrorEvent() => state,
      ConnectionEvent(state: final connection) => state._with(
        connection: connection,
      ),
      // Who is typing is drawn from Task 3 of the app feedback plan on.
      TypingEvent() => state,
      ResetEvent() => Conversation(connection: state.connection),
      SendStarted(:final clientId, :final content) => state._with(
        pending: List.unmodifiable([
          ...state.pending,
          PendingMessage(clientId, content),
        ]),
      ),
      SendFailed(:final clientId) => state._with(
        pending: List.unmodifiable([
          for (final each in state.pending)
            each.clientId == clientId
                ? PendingMessage(each.clientId, each.content, failed: true)
                : each,
        ]),
      ),
      SendDropped(:final clientId) => state._with(
        pending: List.unmodifiable(
          state.pending.where((each) => each.clientId != clientId),
        ),
      ),
    };

/// The pending messages left once the customer's own message came back: the one with
/// its client id, else (an older API) the oldest with the same words. Another device's
/// message, with an id not ours, settles none.
List<PendingMessage> _settled(List<PendingMessage> pending, ChatMessage echo) {
  final clientId = echo.clientId;
  final index = clientId != null
      ? pending.indexWhere((each) => each.clientId == clientId)
      : pending.indexWhere((each) => each.content == echo.content);
  return index < 0
      ? pending
      : List<PendingMessage>.unmodifiable([...pending]..removeAt(index));
}

Conversation _withMessage(Conversation state, ChatMessage message) {
  final messages = state.messages.any((each) => each.id == message.id)
      ? state.messages
      : List<ChatMessage>.unmodifiable([...state.messages, message]);
  return message.senderType == .endUser
      ? state._with(
          messages: messages,
          options: const [],
          limitedFor: null,
          pending: _settled(state.pending, message),
        )
      : state._with(messages: messages, options: message.options);
}

/// A snapshot replaces what came before; only a message of the customer's it had not
/// seen can be one still on its way: an older one with the same words is not it.
Conversation _replayed(Conversation state, SessionSnapshot snapshot) {
  final replayed = snapshot.messages.fold(
    state._with(
      status: snapshot.status,
      ticketId: snapshot.ticketId,
      messages: const [],
      options: const [],
      ended: null,
      pending: const [],
    ),
    _withMessage,
  );
  final known = {for (final each in state.messages) each.id};
  return replayed._with(
    pending: snapshot.messages
        .where(
          (each) => each.senderType == .endUser && !known.contains(each.id),
        )
        .fold<List<PendingMessage>>(state.pending, _settled),
  );
}
