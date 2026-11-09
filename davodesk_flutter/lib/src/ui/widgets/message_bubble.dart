import 'package:material_ui/material_ui.dart';

import '../features/conversation/conversation_view_model.dart';
import '../theme.dart';

/// One message: the customer's on the right in the accent; everyone else's on the left
/// under who wrote it, the AI's as "{name} · AI Agent", with the articles it came from.
class MessageBubble extends StatelessWidget {
  /// Creates the bubble for [item], at most [maxWidth] wide.
  const MessageBubble({
    super.key,
    required this.item,
    required this.maxWidth,
    this.onOpenFile,
  });

  /// The message.
  final BubbleItem item;

  /// The widest the bubble may be.
  final double maxWidth;

  /// Opens one of the message's files.
  final void Function(String url)? onOpenFile;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    if (item.mine) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.78),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(14),
                topEnd: Radius.circular(4),
                bottomStart: Radius.circular(14),
                bottomEnd: Radius.circular(14),
              ),
            ),
            child: Text(
              item.text,
              style: TextStyle(color: colors.onAccent, fontSize: 13.5),
            ),
          ),
        ),
      );
    }
    final label = item.label;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth * 0.84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    if (item.ai)
                      Icon(Icons.auto_awesome, size: 14, color: colors.accent)
                    else
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          label.isEmpty ? '?' : label.characters.first,
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: label,
                          children: [
                            if (item.ai)
                              TextSpan(
                                text: ' · AI Agent',
                                style: TextStyle(
                                  color: colors.ink2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Color.lerp(colors.paper, colors.ink, dark ? 0.08 : 0.05),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(4),
                  topEnd: Radius.circular(14),
                  bottomStart: Radius.circular(14),
                  bottomEnd: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  if (item.sources.isNotEmpty || item.files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final title in item.sources)
                            _Tag(text: title, icon: Icons.article_outlined),
                          for (final file in item.files)
                            _Tag(
                              text: file.name ?? 'File',
                              icon: Icons.attach_file_rounded,
                              onTap: onOpenFile == null
                                  ? null
                                  : () => onOpenFile!(file.url),
                            ),
                        ],
                      ),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon, this.onTap});

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: colors.accent),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.ink2, fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? tag
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: tag,
          );
  }
}
