import 'package:material_ui/material_ui.dart';

import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/recover.dart';
import '../../widgets/state_chip.dart';
import 'messages_view_model.dart';

/// Messages: every conversation, last updated first, and a pencil for a new one.
class MessagesPage extends StatefulWidget {
  /// Creates Messages.
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  MessagesViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model == null) {
      final scope = SupportScope.of(context);
      _model = MessagesViewModel(scope.client, scope.config)..load();
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
      builder: (context, _) => MessagesView(
        state: model.state,
        onOpen: (id) async {
          await model.markSeen(id);
          if (context.mounted) scope.go(context, TicketPlace(id));
        },
        onNew: () => scope.go(context, const ConversationPlace(fresh: true)),
        onRetry: model.load,
        onBack: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// The customer's chats, drawn from [state], with Start a new chat at the bottom.
class MessagesView extends StatelessWidget {
  /// Creates the view.
  const MessagesView({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onNew,
    required this.onRetry,
    required this.onBack,
  });

  /// What to show.
  final MessagesState state;

  /// Opens a chat.
  final void Function(String id) onOpen;

  /// Starts a new chat.
  final VoidCallback onNew;

  /// Loads again after a failure.
  final VoidCallback onRetry;

  /// Goes back.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _Bar(onBack: onBack),
                const Divider(),
                Expanded(
                  child: switch (state) {
                    MessagesState(failed: true) => Center(
                      child: Recover(onRetry: onRetry),
                    ),
                    MessagesState(rows: [], loading: true) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    MessagesState(rows: []) => const _Empty(),
                    MessagesState(:final rows) => ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _ConversationRow(
                        row: rows[i],
                        onTap: () => onOpen(rows[i].id),
                      ),
                    ),
                  },
                ),
                if (!state.failed && !(state.loading && state.rows.isEmpty))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onNew,
                        child: const Text('Start a new chat'),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final tonal = IconButton.styleFrom(
      backgroundColor: colors.rule.withValues(alpha: 0.6),
      foregroundColor: colors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            style: tonal,
            icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Back'),
          ),
          Expanded(
            child: Semantics(
              headingLevel: 1,
              child: Text(
                'Chats',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Balances Back, so the title stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 40, color: colors.ink3),
            const SizedBox(height: 10),
            Text(
              'No chats yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chats with the team will be shown here',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.ink2, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.row, required this.onTap});

  final MessageRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.rule)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  row.initial,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          row.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        row.day,
                        style: TextStyle(color: colors.ink3, fontSize: 12),
                      ),
                    ],
                  ),
                  if (row.line.isNotEmpty)
                    Text(
                      row.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.ink2, fontSize: 13),
                    ),
                  const SizedBox(height: 6),
                  StateChip(status: row.status, reference: row.reference),
                ],
              ),
            ),
            if (row.unread)
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: Semantics(
                  key: const Key('unread'),
                  label: 'Unread',
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
