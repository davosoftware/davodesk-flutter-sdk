import 'package:material_ui/material_ui.dart';

import '../core/scope.dart';
import '../core/support_shell.dart';
import '../theme.dart';

/// The message box: the text, attach (a photo or a PDF), emoji (the system keyboard's),
/// and send. There is no microphone.
class Composer extends StatefulWidget {
  /// Creates the box; [onAttach] is null where nothing can be attached yet.
  const Composer({
    super.key,
    required this.placeholder,
    required this.onSend,
    this.onAttach,
  });

  /// What the empty box says.
  final String placeholder;

  /// Sends the text.
  final void Function(String text) onSend;

  /// Attaches a photo or a file.
  final void Function(AttachFrom from)? onAttach;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _text.clear();
  }

  Future<void> _attach() async {
    final colors = SupportColors.of(context);
    final from = await showModalBottomSheet<AttachFrom>(
      context: context,
      builder: (sheet) => SupportShell(
        colors: colors,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo'),
                onTap: () => Navigator.pop(sheet, AttachFrom.photos),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('File'),
                onTap: () => Navigator.pop(sheet, AttachFrom.files),
              ),
            ],
          ),
        ),
      ),
    );
    if (from != null) widget.onAttach?.call(from);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final ready = _text.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.rule),
      ),
      child: Column(
        children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            minLines: 1,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: colors.ink, fontSize: 14),
            decoration: InputDecoration.collapsed(
              hintText: widget.placeholder,
              hintStyle: TextStyle(color: colors.ink3, fontSize: 14),
            ),
          ),
          Row(
            children: [
              if (widget.onAttach != null)
                IconButton(
                  onPressed: _attach,
                  color: colors.ink2,
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    semanticLabel: 'Attach',
                  ),
                ),
              IconButton(
                onPressed: _focus.requestFocus,
                color: colors.ink2,
                icon: const Icon(
                  Icons.emoji_emotions_outlined,
                  semanticLabel: 'Emoji',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: ready ? _send : null,
                style: IconButton.styleFrom(
                  backgroundColor: ready ? colors.accent : colors.rule,
                  foregroundColor: ready ? colors.onAccent : colors.ink2,
                  disabledBackgroundColor: colors.rule,
                  disabledForegroundColor: colors.ink3,
                ),
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  semanticLabel: 'Send',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
