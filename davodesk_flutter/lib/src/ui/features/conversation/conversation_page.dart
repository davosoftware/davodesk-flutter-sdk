import 'package:material_ui/material_ui.dart';

import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/brand_tile.dart';
import '../../widgets/composer.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/recover.dart';
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

  /// Goes back.
  final VoidCallback onBack;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  final _scroll = ScrollController();
  int _lines = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest line in view as lines arrive.
  void _follow(int lines) {
    if (lines == _lines) return;
    _lines = lines;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

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
                            _follow(lines.length);
                            return ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                              itemCount: lines.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: lines[i],
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
                        child: const Text('Start a new conversation'),
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

  List<Widget> _linesOf(ConversationState state, double width) {
    final colors = SupportColors.of(context);
    final small = TextStyle(color: colors.ink3, fontSize: 11.5);
    Widget centered(String text, {TextStyle? style}) => Center(
      child: Text(text, textAlign: TextAlign.center, style: style ?? small),
    );
    return [
      if (state.tagline case final tagline?)
        centered(tagline, style: TextStyle(color: colors.ink2, fontSize: 11.5)),
      if (state.notice case final notice?)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: colors.rule),
            borderRadius: BorderRadius.circular(12),
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
      for (final item in state.items)
        switch (item) {
          BubbleItem() => MessageBubble(
            key: ValueKey(item.id),
            item: item,
            maxWidth: width - 28,
            onOpenFile: widget.onOpenFile,
          ),
          JoinedItem(:final name) => centered('$name joined'),
        },
      if (state.confirming)
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
      if (state.choices.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 7,
          children: [
            for (final choice in state.choices)
              OutlinedButton(
                onPressed: () => widget.onChoose(choice.key),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: BorderSide(color: colors.accent.withValues(alpha: 0.3)),
                  foregroundColor: colors.accent,
                  backgroundColor: colors.paper,
                ),
                child: Text(choice.label, textAlign: TextAlign.end),
              ),
          ],
        ),
      if (state.offerTeam)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: widget.onTalkToPerson,
            child: const Text('Talk to a person'),
          ),
        ),
      if (state.reconnecting) centered('Reconnecting…'),
      if (state.limited) centered('Too many messages. Try again in a minute.'),
      if (state.endedLine case final line?) centered(line),
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
