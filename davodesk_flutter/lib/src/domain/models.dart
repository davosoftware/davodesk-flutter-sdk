/// The DavoDesk API's shapes the SDK reads, parsed leniently: a missing list is empty and
/// a missing string is null, as the web widget does, so an older or newer API never
/// breaks a screen.
library;

String? _string(Object? value) => value is String ? value : null;
bool _bool(Object? value) => value == true;
int? _int(Object? value) =>
    value is int ? value : (value is num ? value.toInt() : null);
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
List<Map<String, Object?>> _maps(Object? value) =>
    value is List ? value.whereType<Map<String, Object?>>().toList() : const [];
Map<String, Object?>? _map(Object? value) =>
    value is Map<String, Object?> ? value : null;

/// What DavoDesk AI is called when a brand hasn't named its agent.
const defaultAiAgentName = 'DavoDesk AI';

/// A card on Home that links out.
class const HomeLink(final String title, final String url) {
  /// Creates a link.
  this;

  /// Reads a link, or null when it lacks a title or an address.
  static HomeLink? fromJson(Map<String, Object?> json) => switch (json) {
    {'title': String title, 'url': String url} => HomeLink(title, url),
    _ => null,
  };
}

/// A subject the brand offers on the contact form; raising with its [key] sends the
/// ticket where the brand chose.
class const RequestSubject(final String key, final String label) {
  /// Creates a subject.
  this;

  /// Reads a subject, or null when it lacks its key or its words.
  static RequestSubject? fromJson(Map<String, Object?> json) => switch (json) {
    {'key': String key, 'label': String label} => RequestSubject(key, label),
    _ => null,
  };
}

/// The corners of cards, fields, bubbles, chips and buttons; avatars stay round.
enum DavoDeskCorners {
  /// DavoDesk's rounded corners.
  rounded,

  /// Square corners.
  square,
}

/// A channel's look: its colour, corners, title and links.
class const ChannelLook({
  required final String accentColor,
  final String? title,
  final List<HomeLink> homeLinks = const [],

  /// As set in DavoDesk; null from an API that predates it.
  final DavoDeskCorners? corners,
}) {
  /// Creates a [ChannelLook].
  this;

  /// Reads a channel's look.
  factory fromJson(Map<String, Object?> json) => ChannelLook(
    accentColor: _string(json['accent_color']) ?? '#1d4ed8',
    title: _string(json['title']),
    homeLinks: [
      for (final link in _maps(json['home_links'])) ?HomeLink.fromJson(link),
    ],
    corners: switch (json['corners']) {
      'square' => .square,
      'rounded' => .rounded,
      _ => null,
    },
  );
}

/// A channel's public settings: what the screens draw before anything else.
class const ChannelConfig({
  required final String channelId,
  required final String type,
  required final String brandName,
  required final String supportMode,
  final String? logoUrl,
  final String? headerLogoUrl,
  final String aiAgentName = defaultAiAgentName,
  final String? tagline,
  final String? chatNotice,
  final bool answersEnabled = false,
  final bool aiEnabled = false,
  final ChannelLook? appearance,
  final List<RequestSubject> requestSubjects = const [],
}) {
  /// Creates a [ChannelConfig].
  this;

  /// Reads a channel's config; a config without its id or brand name is refused.
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'channel_id': String channelId, 'brand_name': String brandName} =>
      ChannelConfig(
        channelId: channelId,
        type: _string(json['type']) ?? 'app',
        brandName: brandName,
        supportMode: _string(json['support_mode']) ?? 'ai_triage',
        logoUrl: _string(json['logo_url']),
        headerLogoUrl: _string(json['header_logo_url']),
        aiAgentName: _string(json['ai_agent_name']) ?? defaultAiAgentName,
        tagline: _string(json['tagline']),
        chatNotice: _string(json['chat_notice']),
        answersEnabled: _bool(json['answers_enabled']),
        aiEnabled: _bool(json['ai_enabled']),
        appearance: switch (_map(json['appearance'])) {
          final look? => ChannelLook.fromJson(look),
          null => null,
        },
        requestSubjects: [
          for (final subject in _maps(json['request_subjects']))
            ?RequestSubject.fromJson(subject),
        ],
      ),
    _ => throw const FormatException('Not a channel config'),
  };

  /// Whether the brand only answers, with no way to the team (the assistant-only mode).
  bool get answersOnly => supportMode == 'assistant_only';
}

/// A customer session the API opened.
class const OpenedSession({
  required final String sessionToken,
  required final Duration expiresIn,
  required final String brandId,
  final String? customerName,
}) {
  /// Creates a [OpenedSession].
  this;

  /// Reads an opened session.
  factory fromJson(Map<String, Object?> json) => switch (json) {
    {'session_token': String token, 'brand_id': String brandId} =>
      OpenedSession(
        sessionToken: token,
        expiresIn: Duration(seconds: _int(json['expires_in']) ?? 1800),
        brandId: brandId,
        customerName: _string(_map(json['end_user'])?['name']),
      ),
    _ => throw const FormatException('Not an opened session'),
  };
}

/// Who wrote a message.
enum SenderType {
  /// The customer.
  endUser,

  /// DavoDesk AI, the FAQ or intake.
  bot,

  /// A person on the team.
  staff,

  /// One of the team's automations.
  automation;

  /// Reads the API's name for a sender; an unknown one is the team's automation.
  static SenderType parse(Object? value) => switch (value) {
    'end_user' => .endUser,
    'bot' => .bot,
    'staff' => .staff,
    _ => .automation,
  };
}

/// A choice offered under a message, such as a FAQ topic.
class const ChatOption(final String key, final String label) {
  /// Creates a [ChatOption].
  this;
}

/// An article an answer came from.
class const BotSource(final String articleId, final String title) {
  /// Creates a [BotSource].
  this;
}

/// A file on a message.
class const Attachment({
  required final String url,
  required final String contentType,
  final String? name,
  final int? bytes,
}) {
  /// Creates a [Attachment].
  this;

  /// Reads an attachment, or null without an address.
  static Attachment? fromJson(Map<String, Object?> json) => switch (json) {
    {'url': String url} => Attachment(
      url: url,
      contentType: _string(json['content_type']) ?? 'application/octet-stream',
      name: _string(json['original_filename']),
      bytes: _int(json['bytes']),
    ),
    _ => null,
  };
}

/// A message in a conversation or on a ticket.
class const ChatMessage({
  required final String id,
  required final SenderType senderType,
  required final String content,
  final String? senderDisplayName,
  final List<BotSource> botSources = const [],
  final bool confirmationRequested = false,
  final List<ChatOption> options = const [],
  final List<Attachment> attachments = const [],
  final DateTime? sentAt,

  /// DavoDesk AI wrote this bot message; null from an API that predates it, which earns
  /// no ✦ rather than a guess.
  final bool? aiWritten,
}) {
  /// Creates a [ChatMessage].
  this;

  /// Reads a message; the chat-only fields default when a ticket's message lacks them.
  factory fromJson(Map<String, Object?> json) => ChatMessage(
    id: _string(json['id']) ?? '',
    senderType: SenderType.parse(json['sender_type']),
    content: _string(json['content']) ?? '',
    senderDisplayName: _string(json['sender_display_name']),
    botSources: [
      for (final source in _maps(json['bot_sources']))
        if (source case {'article_id': String id, 'title': String title})
          BotSource(id, title),
    ],
    confirmationRequested: _bool(json['confirmation_requested']),
    options: [
      for (final option in _maps(json['options']))
        if (option case {'key': String key, 'label': String label})
          ChatOption(key, label),
    ],
    attachments: [
      for (final attachment in _maps(json['attachments']))
        ?Attachment.fromJson(attachment),
    ],
    sentAt: _date(json['sent_at']),
    aiWritten: switch (json['ai_written']) {
      final bool written => written,
      _ => null,
    },
  );
}

/// The newest message a customer may see on a ticket.
class const LastMessage({
  required final SenderType senderType,
  required final String preview,
  final String? senderDisplayName,
}) {
  /// Creates a [LastMessage].
  this;

  /// Reads a last message.
  factory fromJson(Map<String, Object?> json) => LastMessage(
    senderType: SenderType.parse(json['sender_type']),
    preview: _string(json['preview']) ?? '',
    senderDisplayName: _string(json['sender_display_name']),
  );
}

/// The team's request for a rating, and the customer's answer.
class const Satisfaction({
  final DateTime? requestedAt,
  final String? rating,
  final String? comment,
}) {
  /// Creates a [Satisfaction].
  this;

  /// Reads a satisfaction record.
  factory fromJson(Map<String, Object?> json) => Satisfaction(
    requestedAt: _date(json['requested_at']),
    rating: _string(json['rating']),
    comment: _string(json['comment']),
  );

  /// Whether the team asked for a rating that hasn't been given.
  bool get awaitingRating => requestedAt != null && rating == null;
}

/// One of the customer's tickets, as the list shows it.
class const TicketSummary({
  required final String id,
  required final String subject,
  required final String status,
  final DateTime? createdAt,
  final DateTime? updatedAt,
  final LastMessage? lastMessage,
  final Satisfaction? satisfaction,
}) {
  /// Creates a [TicketSummary].
  this;

  /// Reads a ticket summary.
  factory fromJson(Map<String, Object?> json) => TicketSummary(
    id: _string(json['id']) ?? '',
    subject: _string(json['subject']) ?? '',
    status: _string(json['status']) ?? 'open',
    createdAt: _date(json['created_at']),
    updatedAt: _date(json['updated_at']),
    lastMessage: switch (_map(json['last_message'])) {
      final last? => LastMessage.fromJson(last),
      null => null,
    },
    satisfaction: switch (_map(json['satisfaction'])) {
      final record? => Satisfaction.fromJson(record),
      null => null,
    },
  );
}

/// One of the customer's tickets, with its messages.
class const CustomerTicket({
  required final TicketSummary summary,
  final List<ChatMessage> messages = const [],
  final String? mergedInto,
  final bool resolvedByAi = false,
  final bool reopenable = false,
}) {
  /// Creates a [CustomerTicket].
  this;

  /// Reads a ticket.
  factory fromJson(Map<String, Object?> json) => CustomerTicket(
    summary: TicketSummary.fromJson(json),
    messages: [
      for (final message in _maps(json['messages']))
        ChatMessage.fromJson(message),
    ],
    mergedInto: _string(json['merged_into']),
    resolvedByAi: _bool(json['resolved_by_ai']),
    reopenable: _bool(json['reopenable']),
  );

  /// The ticket's id.
  String get id => summary.id;

  /// The ticket's subject.
  String get subject => summary.subject;

  /// The ticket's status.
  String get status => summary.status;
}

/// A ticket raised from the contact form; [resumed] means it was added to an open one.
class const RaisedTicket(final bool resumed, final CustomerTicket ticket) {
  /// Creates a [RaisedTicket].
  this;
}

/// A help-centre article.
class const PublicArticle({
  required final String id,
  required final String title,
  required final String body,
  final String? categoryId,
}) {
  /// Creates a [PublicArticle].
  this;

  /// Reads an article.
  factory fromJson(Map<String, Object?> json) => PublicArticle(
    id: _string(json['id']) ?? '',
    title: _string(json['title']) ?? '',
    body: _string(json['body']) ?? '',
    categoryId: _string(json['category_id']),
  );
}

/// A search hit in the help centre.
class const ArticleHit({
  required final String articleId,
  required final String title,
  final String excerpt = '',
}) {
  /// Creates a [ArticleHit].
  this;

  /// Reads a search hit.
  factory fromJson(Map<String, Object?> json) => ArticleHit(
    articleId: _string(json['article_id']) ?? '',
    title: _string(json['title']) ?? '',
    excerpt: _string(json['excerpt']) ?? '',
  );
}

/// A help-centre collection, with its published articles counted and its sections.
class const CategoryNode({
  required final String id,
  required final String name,
  final String description = '',
  final int articleCount = 0,
  final List<CategoryNode> sections = const [],
}) {
  /// Creates a [CategoryNode].
  this;

  /// Reads a collection.
  factory fromJson(Map<String, Object?> json) => CategoryNode(
    id: _string(json['id']) ?? '',
    name: _string(json['name']) ?? '',
    description: _string(json['description']) ?? '',
    articleCount: _int(json['article_count']) ?? 0,
    sections: [
      for (final section in _maps(json['sections']))
        CategoryNode.fromJson(section),
    ],
  );

  /// The articles in this collection and its sections.
  int get totalArticles =>
      articleCount +
      sections.fold(0, (sum, section) => sum + section.totalArticles);
}

/// A page of published articles.
class const ArticlePage(final int total, final List<PublicArticle> articles) {
  /// Creates a [ArticlePage].
  this;
}

/// The server's answer to a chat call: whether it took it, and whether the team now has
/// the conversation as [ticketId].
class const ChatAck({
  required final bool ok,
  final bool handedOff = false,
  final String? ticketId,
  final String? error,
}) {
  /// Creates a [ChatAck].
  this;

  /// Reads an answer; anything but a map is a refusal.
  factory fromJson(Object? json) => switch (json) {
    final Map<String, Object?> map => ChatAck(
      ok: _bool(map['ok']),
      handedOff: _bool(map['handed_off']),
      ticketId: _string(map['ticket_id']),
      error: _string(map['error']),
    ),
    _ => const ChatAck(ok: false),
  };
}

/// What the chat socket sends on connecting: the conversation so far.
class const SessionSnapshot({
  required final String id,
  required final String status,
  final String? ticketId,
  final List<ChatMessage> messages = const [],
}) {
  /// Creates a [SessionSnapshot].
  this;

  /// Reads a snapshot.
  factory fromJson(Map<String, Object?> json) => SessionSnapshot(
    id: _string(json['id']) ?? '',
    status: _string(json['status']) ?? 'bot',
    ticketId: _string(json['ticket_id']),
    messages: [
      for (final message in _maps(json['messages']))
        ChatMessage.fromJson(message),
    ],
  );
}
