import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/brand_tile.dart';
import '../../widgets/composer.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/recover.dart';
import '../../widgets/slide_in.dart';
import '../../widgets/typing_bubble.dart';
import 'conversation_view_model.dart';

/// The live conversation with DavoDesk AI, then the team.
class ConversationPage extends StatefulWidget {
  /// Creates the page; [fresh] starts a new conversation first.
  const ConversationPage({super.key, this.fresh = false});

  /// Whether to start a new conversation.
  final bool fresh;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  ConversationViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model == null) {
      final scope = SupportScope.of(context);
      _model = ConversationViewModel(
        scope.client,
        scope.config,
        scope.pickAttachment,
        fresh: widget.fresh,
      )..load();
    }
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = SupportScope.of(context);
    final model = _model!;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => ConversationView(
        state: model.state,
        onSend: model.send,
        onChoose: model.choose,
        onSolved: model.solved,
        onTalkToPerson: model.talkToPerson,
        onStartNew: model.startNew,
        onAttach: model.attach,
        onOpenFile: (url) => scope.openLink(Uri.parse(url)),
        onResend: model.resend,
        onRefresh: model.refresh,
        onRetry: model.load,
        onBack: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// The conversation drawn from [state].
class ConversationView extends StatefulWidget {
  /// Creates the view.
  const ConversationView({
    super.key,
    required this.state,
    required this.onSend,
    required this.onChoose,
    required this.onSolved,
    required this.onTalkToPerson,
    required this.onStartNew,
    required this.onAttach,
    required this.onOpenFile,
    required this.onRetry,
    required this.onResend,
    required this.onRefresh,
    required this.onBack,
  });

  /// What to show.
  final ConversationState state;

  /// Sends a message.
  final void Function(String text) onSend;

  /// Answers a choice.
  final void Function(String key) onChoose;

  /// Answers That solved it.
  final VoidCallback onSolved;

  /// Asks for a person.
  final VoidCallback onTalkToPerson;

  /// Starts a new conversation.
  final VoidCallback onStartNew;

  /// Attaches a photo or a file.
  final void Function(AttachFrom from) onAttach;

  /// Opens a message's file.
  final void Function(String url) onOpenFile;

  /// Opens the conversation again after a failure.
  final VoidCallback onRetry;

  /// Sends a message the server refused again, by its client id.
  final void Function(String clientId) onResend;

  /// Asks for the conversation again, when the customer pulls it down.
  final Future<void> Function() onRefresh;

  /// Goes back.
  final VoidCallback onBack;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _scroll = ScrollController();
  List<Object?> _drawn = const [];

  /// The items the chat showed when it first had any: they stay still (spec §8).
  Set<String>? _firstShown;

  @override
  void initState() {
    super.initState();
    _noteFirstShown();
  }

  @override
  void didUpdateWidget(ConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _noteFirstShown();
  }

  void _noteFirstShown() {
    final items = widget.state.items;
    if (_firstShown == null) {
      if (items.isNotEmpty) {
        _firstShown = {for (final item in items) _keyOf(item)};
      }
    } else if (!items.any((item) => item is TypingItem)) {
      // The dots slide in each time they come back.
      _firstShown!.remove(_typing);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the chat at its newest line: after a frame whose lines, or room, changed.
  void _follow(List<Object?> drawn) {
    if (listEquals(drawn, _drawn)) return;
    _drawn = drawn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  static const _typing = 'typing';

  static String _keyOf(ChatItem item) => switch (item) {
    BubbleItem(:final id) => id,
    JoinedItem() => 'joined',
    TypingItem() => _typing,
  };

  /// Whether [item] fades in and rises: a bubble, or the dots, that came after the chat
  /// first showed; not the customer's own message back from the server, whose "Sending…"
  /// bubble already did.
  bool _slides(ChatItem item) =>
      _firstShown != null &&
      !_firstShown!.contains(_keyOf(item)) &&
      switch (item) {
        BubbleItem(mine: true, status: BubbleStatus.sent) ||
        JoinedItem() => false,
        BubbleItem() || TypingItem() => true,
      };

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final state = widget.state;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _Header(state: state, onBack: widget.onBack),
                Expanded(
                  child: state.failed
                      ? Center(child: Recover(onRetry: widget.onRetry))
                      : LayoutBuilder(
                          builder: (context, box) {
                            final lines = _linesOf(state, box.maxWidth);
                            _follow([
                              box.maxHeight,
                              for (final line in lines) line.key,
                              // "Not sent · Retry" makes a bubble taller.
                              for (final item in state.items)
                                if (item is BubbleItem) item.status,
                            ]);
                            return RefreshIndicator(
                              onRefresh: widget.onRefresh,
                              color: colors.accent,
                              // Every line laid out (chats are short), so the end is
                              // known and a jump to it lands. Expanded, so the whole
                              // pane scrolls and pulls, under a short chat too.
                              child: SizedBox.expand(
                                child: SingleChildScrollView(
                                  controller: _scroll,
                                  // A short chat still pulls down to refresh.
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    4,
                                    14,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: lines,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (state.attachError case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      error,
                      style: TextStyle(color: colors.warn, fontSize: 12.5),
                    ),
                  ),
                if (state.closed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onStartNew,
                        child: const Text('Start a new chat'),
                      ),
                    ),
                  )
                else if (state.showComposer && !state.failed)
                  Composer(
                    placeholder: state.placeholder,
                    onSend: widget.onSend,
                    onAttach: state.canAttach ? widget.onAttach : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The chat's lines, each keyed, so a new one is a new line rather than an old one
  /// changed.
  List<Widget> _linesOf(ConversationState state, double width) {
    final colors = SupportColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final small = TextStyle(color: colors.ink3, fontSize: 11.5);
    Widget line(String key, Widget child, {bool slides = false}) => Padding(
      key: ValueKey('line:$key'),
      padding: const EdgeInsets.only(bottom: 10),
      child: slides && !still ? SlideIn(child: child) : child,
    );
    Widget centered(String key, String text, {TextStyle? style}) => line(
      key,
      Center(
        child: Text(text, textAlign: TextAlign.center, style: style ?? small),
      ),
    );
    return [
      if (state.tagline case final tagline?)
        centered(
          'tagline',
          tagline,
          style: TextStyle(color: colors.ink2, fontSize: 11.5),
        ),
      if (state.notice case final notice?)
        line(
          'notice',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: colors.rule),
              borderRadius: colors.corner(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colors.ink3),
                Expanded(
                  child: Text(
                    notice,
                    style: TextStyle(
                      color: colors.ink2,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      for (final item in state.items)
        line(_keyOf(item), switch (item) {
          BubbleItem() => MessageBubble(
            key: ValueKey(item.id),
            item: item,
            maxWidth: width - 28,
            onOpenFile: widget.onOpenFile,
            onResend: widget.onResend,
          ),
          JoinedItem(:final name) => Center(
            child: Text(
              '$name joined',
              textAlign: TextAlign.center,
              style: small,
            ),
          ),
          TypingItem() => TypingBubble(
            key: const ValueKey('typing'),
            item: item,
          ),
        }, slides: _slides(item)),
      if (state.confirming)
        line(
          'confirming',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: widget.onSolved,
                child: const Text('That solved it'),
              ),
              OutlinedButton(
                onPressed: widget.onTalkToPerson,
                child: const Text('Talk to a person'),
              ),
            ],
          ),
        ),
      if (state.choices.isNotEmpty)
        line(
          'choices',
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 7,
            children: [
              for (final choice in state.choices)
                OutlinedButton(
                  onPressed: () => widget.onChoose(choice.key),
                  style: OutlinedButton.styleFrom(
                    shape: colors.corners == DavoDeskCorners.square
                        ? const RoundedRectangleBorder()
                        : const StadiumBorder(),
                    side: BorderSide(
                      color: colors.accent.withValues(alpha: 0.3),
                    ),
                    foregroundColor: colors.accentInk,
                    backgroundColor: colors.paper,
                  ),
                  child: Text(choice.label, textAlign: TextAlign.end),
                ),
            ],
          ),
        ),
      if (state.offerTeam)
        line(
          'offer-team',
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: widget.onTalkToPerson,
              child: const Text('Talk to a person'),
            ),
          ),
        ),
      if (state.reconnecting) centered('reconnecting', 'Reconnecting…'),
      if (state.limited)
        centered('limited', 'Too many messages. Try again in a minute.'),
      if (state.endedLine case final ended?) centered('ended', ended),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onBack});

  final ConversationState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          spacing: 10,
          children: [
            IconButton(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: colors.rule.withValues(alpha: 0.6),
                foregroundColor: colors.ink,
              ),
              icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Back'),
            ),
            BrandTile(logoUrl: state.logoUrl, name: state.brandName, size: 34),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    headingLevel: 1,
                    child: Text(
                      state.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.ink,
                        fontFamily: colors.headingFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    state.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.ink2, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
