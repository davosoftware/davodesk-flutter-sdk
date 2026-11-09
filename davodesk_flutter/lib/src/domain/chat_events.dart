/// What moves a chat on: what the server says (the integration guide, §4), and the
/// customer starting anew.
library;

import 'models.dart';

/// Something that moves a conversation on.
sealed class ConversationEvent {
  /// Creates an event.
  const ConversationEvent();
}

/// The customer starts a new conversation after the last one ended.
final class const ResetEvent() extends ConversationEvent {
  /// Creates the reset.
  this;
}

/// What the chat socket reports.
sealed class ChatEvent extends ConversationEvent {
  /// Creates an event.
  const ChatEvent();
}

/// The server admitted the socket and sent the conversation so far.
final class const SessionEvent(final SessionSnapshot snapshot)
    extends ChatEvent {
  /// Creates a [SessionEvent].
  this;
}

/// A message in the conversation, the customer's own included.
final class const MessageEvent(final ChatMessage message) extends ChatEvent {
  /// Creates a [MessageEvent].
  this;
}

/// The conversation went to the team as [ticketId]; [resumed] means it joined the
/// customer's open ticket.
final class const HandoffEvent({
  required final String ticketId,
  required final bool resumed,
  required final String reason,
}) extends ChatEvent {
  /// Creates a [HandoffEvent].
  this;
}

/// A person on the team joined; [displayName] is null when they have no public name.
final class const HumanJoinedEvent(final String? displayName)
    extends ChatEvent {
  /// Creates a [HumanJoinedEvent].
  this;
}

/// The conversation ended, for [reason], such as `ticket_closed` or `helped`.
final class const EndedEvent(final String reason) extends ChatEvent {
  /// Creates an [EndedEvent].
  this;
}

/// The customer said DavoDesk AI solved it; [ticketId] records it.
final class const ResolvedEvent(final String ticketId) extends ChatEvent {
  /// Creates a [ResolvedEvent].
  this;
}

/// The server refused something: [code], with [retryAfter] seconds on `RATE_LIMITED`.
final class const ChatErrorEvent(final String code, {final int? retryAfter})
    extends ChatEvent {
  /// Creates a [ChatErrorEvent].
  this;
}

/// How the connection stands now.
final class const ConnectionEvent(final ChatConnection state)
    extends ChatEvent {
  /// Creates a [ConnectionEvent].
  this;
}

/// How the chat's connection stands.
enum ChatConnection {
  /// Opening the session and the socket.
  connecting,

  /// The server admitted the socket.
  live,

  /// The connection dropped; it comes back by itself.
  reconnecting,
}
