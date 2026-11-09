import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart';
import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/page_bar.dart';
import '../../widgets/recover.dart';
import 'help_view_model.dart';

/// Help: search, then the brand's collections.
class HelpPage extends StatefulWidget {
  /// Creates Help.
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  HelpViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model ??= HelpViewModel(SupportScope.of(context).client)..load();
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
                  title: 'Help',
                  centered: true,
                  onBack: () => Navigator.maybePop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    onSubmitted: model.search,
                    onChanged: (text) {
                      if (text.trim().isEmpty) model.search('');
                    },
                    decoration: InputDecoration(
                      hintText: 'Search help articles',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: colors.shelf,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: model,
                    builder: (context, _) => _results(context, scope, model),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(
    BuildContext context,
    SupportScope scope,
    HelpViewModel model,
  ) {
    final colors = SupportColors.of(context);
    if (model.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (model.hits case final hits?) {
      if (hits.isEmpty) {
        return Center(
          child: Text(
            'No articles found.',
            style: TextStyle(color: colors.ink2),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: hits.length,
        itemBuilder: (context, i) => HelpRow(
          title: hits[i].title,
          line: hits[i].excerpt,
          onTap: () => scope.go(context, ArticlePlace(hits[i].articleId)),
        ),
      );
    }
    return switch (model.state) {
      Loading(failed: true) => Center(child: Recover(onRetry: model.load)),
      Loading(value: final List<CategoryNode> collections) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: collections.length,
        itemBuilder: (context, i) => HelpRow(
          title: collections[i].name,
          line: collections[i].description,
          icon: Icons.folder_outlined,
          onTap: () => scope.go(
            context,
            CollectionPlace(collections[i].id, collections[i].name),
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// A row in Help: a collection or an article, with a line under it.
class HelpRow extends StatelessWidget {
  /// Creates the row.
  const HelpRow({
    super.key,
    required this.title,
    required this.onTap,
    this.line = '',
    this.icon = Icons.article_outlined,
  });

  /// The collection's or the article's title.
  final String title;

  /// A line under it.
  final String line;

  /// The row's icon.
  final IconData icon;

  /// Opens it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: colors.accent),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.ink2, fontSize: 13),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.ink3),
          ],
        ),
      ),
    );
  }
}
