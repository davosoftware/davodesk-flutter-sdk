import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart';
import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/page_bar.dart';
import '../../widgets/recover.dart';
import 'help_page.dart';
import 'help_view_model.dart';

/// A help-centre collection's articles.
class CollectionPage extends StatefulWidget {
  /// Creates the page for the collection [id], called [name].
  const CollectionPage({super.key, required this.id, required this.name});

  /// The collection's id.
  final String id;

  /// The collection's name.
  final String name;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  ReadViewModel<ArticlePage>? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = SupportScope.of(context).client;
    _model ??= ReadViewModel(() => client.articles(categoryId: widget.id))
      ..load();
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
    final colors = SupportColors.of(context);
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                PageBar(
                  title: widget.name,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: model,
                    builder: (context, _) => switch (model.state) {
                      Loading(failed: true) => Center(
                        child: Recover(onRetry: model.load),
                      ),
                      Loading(value: ArticlePage(articles: [])) => Center(
                        child: Text(
                          'No articles here yet.',
                          style: TextStyle(color: colors.ink2),
                        ),
                      ),
                      Loading(value: ArticlePage(:final articles)) =>
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: articles.length,
                          itemBuilder: (context, i) => HelpRow(
                            title: articles[i].title,
                            onTap: () =>
                                scope.go(context, ArticlePlace(articles[i].id)),
                          ),
                        ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
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
