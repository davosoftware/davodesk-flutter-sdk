import 'package:material_ui/material_ui.dart';

import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/page_bar.dart';
import '../../widgets/recover.dart';
import '../../widgets/state_chip.dart';
import 'ticket_view_model.dart';

/// One of the customer's tickets.
class TicketPage extends StatefulWidget {
  /// Creates the page for the ticket [id].
  const TicketPage({super.key, required this.id});

  /// The ticket's id.
  final String id;

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  TicketViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model == null) {
      final scope = SupportScope.of(context);
      _model = TicketViewModel(scope.client, scope.config, widget.id)..load();
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
      builder: (context, _) => TicketView(
        state: model.state,
        onRate: model.rate,
        onReopen: model.reopen,
        onContinue: () => scope.go(context, const ConversationPlace()),
        onStartNew: () =>
            scope.go(context, const ConversationPlace(fresh: true)),
        onOpenFile: (url) => scope.openLink(Uri.parse(url)),
        onRetry: model.load,
        onBack: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// A ticket drawn from [state].
class TicketView extends StatelessWidget {
  /// Creates the view.
  const TicketView({
    super.key,
    required this.state,
    required this.onRate,
    required this.onReopen,
    required this.onContinue,
    required this.onStartNew,
    required this.onOpenFile,
    required this.onRetry,
    required this.onBack,
  });

  /// What to show.
  final TicketState state;

  /// Rates the help.
  final Future<void> Function(String rating, String? comment) onRate;

  /// Reopens the ticket.
  final VoidCallback onReopen;

  /// Goes on in the conversation.
  final VoidCallback onContinue;

  /// Starts a new conversation.
  final VoidCallback onStartNew;

  /// Opens a message's file.
  final void Function(String url) onOpenFile;

  /// Reads the ticket again after a failure.
  final VoidCallback onRetry;

  /// Goes back.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final small = TextStyle(color: colors.ink3, fontSize: 11.5);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                PageBar(title: state.subject, onBack: onBack),
                Expanded(
                  child: switch (state) {
                    TicketState(failed: true) => Center(
                      child: Recover(onRetry: onRetry),
                    ),
                    TicketState(loading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _ => LayoutBuilder(
                      builder: (context, box) {
                        final lines = [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: StateChip(
                              status: state.status,
                              reference: state.reference,
                            ),
                          ),
                          for (final item in state.items)
                            MessageBubble(
                              key: ValueKey(item.id),
                              item: item,
                              maxWidth: box.maxWidth - 28,
                              onOpenFile: onOpenFile,
                            ),
                          if (state.askRating) _RatingCard(onRate: onRate),
                          if (state.reopenable)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Not fixed after all? ',
                                  style: TextStyle(
                                    color: colors.ink2,
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: onReopen,
                                  child: const Text('Reopen it'),
                                ),
                              ],
                            ),
                          if (state.closed)
                            Center(
                              child: Text(
                                'This conversation was closed.',
                                style: small,
                              ),
                            ),
                        ];
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          itemCount: lines.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: lines[i],
                          ),
                        );
                      },
                    ),
                  },
                ),
                if (!state.loading &&
                    !state.failed &&
                    (state.closed || state.open))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: state.closed
                          ? FilledButton(
                              onPressed: onStartNew,
                              child: const Text('Start a new conversation'),
                            )
                          : FilledButton(
                              onPressed: onContinue,
                              child: const Text('Continue the conversation'),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "How was the help?": Good or Bad, an optional comment, and Send.
class _RatingCard extends StatefulWidget {
  const _RatingCard({required this.onRate});

  final Future<void> Function(String rating, String? comment) onRate;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  final _comment = TextEditingController();
  String? _rating;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final rating = _rating;
    if (rating == null || _sending) return;
    setState(() => _sending = true);
    final comment = _comment.text.trim();
    await widget.onRate(rating, comment.isEmpty ? null : comment);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'How was the help?',
            style: TextStyle(
              color: colors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'good', label: Text('Good')),
              ButtonSegment(value: 'bad', label: Text('Bad')),
            ],
            selected: {?_rating},
            emptySelectionAllowed: true,
            onSelectionChanged: (selected) =>
                setState(() => _rating = selected.firstOrNull),
          ),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Anything to add? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton(
            onPressed: _rating == null || _sending ? null : _send,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
