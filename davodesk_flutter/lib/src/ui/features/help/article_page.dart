import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart';
import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/page_bar.dart';
import '../../widgets/powered_by.dart';
import '../../widgets/recover.dart';
import 'help_view_model.dart';

/// One help article, with "Was this helpful?".
class ArticlePage extends StatefulWidget {
  /// Creates the page for the article [id].
  const ArticlePage({super.key, required this.id});

  /// The article's id.
  final String id;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  ArticleViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model ??= ArticleViewModel(SupportScope.of(context).client, widget.id)
      ..load();
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model!;
    final colors = SupportColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) {
                return Column(
                  children: [
                    PageBar(
                      title: 'Help',
                      centered: true,
                      onBack: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: switch (model.state) {
                        Loading(failed: true) => Center(
                          child: Recover(onRetry: model.load),
                        ),
                        Loading(value: final PublicArticle article) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              article.title,
                              style: TextStyle(
                                color: colors.ink,
                                fontFamily: colors.headingFontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              article.body,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 14.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _Helped(
                              voted: model.voted,
                              onVote: (helpful) => model.vote(helpful: helpful),
                            ),
                          ],
                        ),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
                    ),
                    // Pinned to the bottom of the screen, under what scrolls.
                    const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 10),
                      child: PoweredBy(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Helped extends StatelessWidget {
  const _Helped({required this.voted, required this.onVote});

  final bool voted;
  final void Function(bool helpful) onVote;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    if (voted) {
      return Text(
        'Thanks for telling us.',
        style: TextStyle(color: colors.ink2, fontSize: 13.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          'Was this helpful?',
          style: TextStyle(
            color: colors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => onVote(true),
              child: const Text('Yes'),
            ),
            OutlinedButton(
              onPressed: () => onVote(false),
              child: const Text('No'),
            ),
          ],
        ),
      ],
    );
  }
}
