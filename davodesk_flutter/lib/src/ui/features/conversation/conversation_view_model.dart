import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../client.dart';
import '../../../data/services/api_service.dart';
import '../../../domain/models.dart';
import '../../core/scope.dart';
import '../../words.dart';

final _log = Logger('DavoDesk');

/// The types the API takes as attachments.
const attachmentTypes = {
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/heic',
  'application/pdf',
};

/// The largest attachment the API takes: 10 MB.
const maxAttachmentBytes = 10 * 1024 * 1024;

/// A line in the conversation.
sealed class ChatItem {
  /// Creates an item.
  const ChatItem();
}

/// A message: the customer's ([mine]), or someone's under a [label] (the AI's carry
/// [ai]), with the articles it came from and its files.
final class const BubbleItem({
  required final String id,
  required final String text,
  final bool mine = false,
  final String? label,
  final bool ai = false,
  final List<String> sources = const [],
  final List<Attachment> files = const [],
}) extends ChatItem {
  /// Creates a [BubbleItem].
  this;
}

/// "{name} joined".
final class const JoinedItem(final String name) extends ChatItem {
  /// Creates a [JoinedItem].
  this;
}

/// What the conversation shows.
class const ConversationState({
  required final String title,
  required final String subtitle,
  required final String brandName,
  final String? logoUrl,
  final String? tagline,
  final String? notice,
  final List<ChatItem> items = const [],
  final List<ChatOption> choices = const [],
  final bool confirming = false,
  final bool offerTeam = false,
  final bool reconnecting = false,
  final bool limited = false,
  final String? endedLine,
  final bool closed = false,
  final bool showComposer = true,
  final bool canAttach = false,
  final String placeholder = 'Ask a question…',
  final String? attachError,
  final bool failed = false,
}) {
  /// Creates a [ConversationState].
  this;
}

/// The conversation's state: the live chat as the screens draw it, and what the
/// customer can do in it.
class ConversationViewModel extends ChangeNotifier {
  /// Creates the view model over [_client] for the channel [_config]; [_pick] picks
  /// attachments, and [_fresh] starts a new conversation first.
  ConversationViewModel(
    this._client,
    this._config,
    this._pick, {
    this._fresh = false,
  }) {
    _client.conversation.addListener(notifyListeners);
  }

  final DavoDeskClient _client;
  final ChannelConfig _config;
  final Future<UploadFile?> Function(AttachFrom from) _pick;
  bool _fresh;
  bool _failed = false;
  String? _attachError;

  /// What the conversation shows now.
  ConversationState get state {
    final chat = _client.conversation.value;
    final brand = _config.brandName;
    final ai = _config.aiAgentName;
    final person = chat.humanJoined
        ? switch (chat.agentName?.trim()) {
            final String name when name.isNotEmpty => name,
            _ => teamName(brand),
          }
        : null;
    final reference = switch (chat.ticketId) {
      final id? => ' · ${referenceOf(id)}',
      null => '',
    };
    final ended = chat.ended;
    final closed = ended == 'ticket_closed';
    final last = chat.messages.lastOrNull;
    final confirming =
        ended == null &&
        last != null &&
        last.senderType == SenderType.bot &&
        last.confirmationRequested;
    final firstStaff = chat.messages.indexWhere(
      (message) => message.senderType == SenderType.staff,
    );
    final joinedAt = person == null
        ? -1
        : (firstStaff >= 0 ? firstStaff : chat.messages.length);
    return ConversationState(
      title: person ?? ai,
      subtitle: closed
          ? 'Closed$reference'
          : person != null
          ? '${teamName(brand)}$reference'
          : 'The team can also help',
      brandName: brand,
      logoUrl: _config.logoUrl,
      tagline: _config.tagline,
      notice: _config.chatNotice,
      items: [
        for (final (index, message) in chat.messages.indexed) ...[
          if (index == joinedAt) JoinedItem(person!),
          bubbleOf(message, brand: brand, ai: ai),
        ],
        if (joinedAt == chat.messages.length) JoinedItem(person!),
      ],
      choices: ended == null ? chat.options : const [],
      confirming: confirming,
      offerTeam: ended == null && chat.status == 'bot' && !confirming,
      reconnecting: chat.connection == .reconnecting,
      limited: chat.limitedFor != null,
      endedLine: closed
          ? 'This chat was closed.'
          : ended != null && ended != 'helped'
          ? 'This chat has ended.'
          : null,
      closed: closed,
      showComposer: ended == null && chat.options.isEmpty,
      canAttach: chat.ticketId != null,
      placeholder: chat.humanJoined ? 'Write a message…' : 'Ask a question…',
      attachError: _attachError,
      failed: _failed,
    );
  }

  /// Opens the chat, or a new one when asked to.
  Future<void> load() async {
    _failed = false;
    notifyListeners();
    try {
      if (_fresh) {
        _fresh = false;
        await _client.startNew();
      }
      await _client.start();
    } on Object catch (error) {
      _log.fine('The conversation could not open: $error');
      _failed = true;
    }
    notifyListeners();
  }

  /// Sends the customer's message.
  Future<void> send(String text) => _client.send(text.trim());

  /// Answers a choice.
  Future<void> choose(String key) => _client.choose(key);

  /// Answers "Did this solve it?" with That solved it.
  Future<void> solved() => _client.confirm(solved: true);

  /// Asks for a person on the team.
  Future<void> talkToPerson() => _client.talkToPerson();

  /// Starts a new conversation.
  Future<void> startNew() => _client.startNew();

  /// Picks a photo or a file and attaches it to the conversation's ticket, when it is
  /// one the API takes.
  Future<void> attach(AttachFrom from) async {
    final ticketId = _client.conversation.value.ticketId;
    if (ticketId == null) return;
    _attachError = null;
    notifyListeners();
    final file = await _pick(from);
    if (file == null) return;
    if (!attachmentTypes.contains(file.contentType)) {
      _attachError = 'Photos and PDFs only.';
    } else if (file.bytes.length > maxAttachmentBytes) {
      _attachError = 'Files can be up to 10 MB.';
    } else {
      try {
        await _client.attach(ticketId, [file]);
      } on Object catch (error) {
        _log.fine('The attachment did not go: $error');
        _attachError = 'Something went wrong here.';
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _client.conversation.removeListener(notifyListeners);
    super.dispose();
  }
}

/// A message as a bubble: the AI's under its name, a person's under theirs.
BubbleItem bubbleOf(
  ChatMessage message, {
  required String brand,
  required String ai,
}) => BubbleItem(
  id: message.id,
  text: message.content,
  mine: message.senderType == SenderType.endUser,
  label: switch (message.senderType) {
    .endUser => null,
    .bot => ai,
    _ => speakerName(
      message.senderType,
      message.senderDisplayName,
      brand: brand,
      aiName: ai,
    ),
  },
  ai: message.senderType == SenderType.bot,
  sources: [for (final source in message.botSources) source.title],
  files: message.attachments,
);
