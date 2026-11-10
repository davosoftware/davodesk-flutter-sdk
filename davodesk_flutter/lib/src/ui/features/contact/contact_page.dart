import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../domain/models.dart' show RequestSubject;
import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/page_bar.dart';
import '../../words.dart';
import 'contact_view_model.dart';

/// Send us a message: raises a ticket without chat; the reply comes to Messages.
class ContactPage extends StatefulWidget {
  /// Creates the form.
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _subject = TextEditingController();
  final _extra = TextEditingController();
  final _message = TextEditingController();
  ContactViewModel? _model;

  @override
  void initState() {
    super.initState();
    for (final field in [_subject, _message]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model ??= ContactViewModel(SupportScope.of(context).client);
  }

  @override
  void dispose() {
    _subject.dispose();
    _extra.dispose();
    _message.dispose();
    _model?.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final scope = SupportScope.of(context);
    final raised = await _model!.send(
      subject: _subject.text,
      message: _message.text,
      extraLabel: scope.contactForm?.extraField?.label,
      extraValue: _extra.text,
      subjects: scope.config.requestSubjects,
    );
    if (raised != null && mounted) {
      // Sent: an emptied form can't send the same message twice.
      for (final field in [_subject, _extra, _message]) {
        field.clear();
      }
      scope.onRaised?.call(raised);
      scope.go(context, TicketPlace(raised.ticket.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SupportScope.of(context);
    final colors = SupportColors.of(context);
    final model = _model!;
    final form = scope.contactForm;
    final note = form?.note;
    final extra = form?.extraField;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                PageBar(
                  title: 'Send us a message',
                  centered: true,
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: model,
                    builder: (context, _) {
                      final ready =
                          _subject.text.trim().isNotEmpty &&
                          _message.text.trim().isNotEmpty &&
                          !model.sending;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          Text(
                            'Have a question about your order or our services? '
                            'Our team is here to help.',
                            style: TextStyle(
                              color: colors.ink2,
                              fontSize: 13.5,
                            ),
                          ),
                          if (note != null && note.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _Note(text: note),
                          ],
                          if (model.raised case final raised?) ...[
                            const SizedBox(height: 14),
                            _Banner(
                              text: raised.resumed
                                  ? 'Added to your open request '
                                        '${referenceOf(raised.ticket.id)}'
                                  : 'Sent. We’ll reply in Chats.',
                              color: colors.ok,
                              background: colors.okSoft,
                            ),
                          ],
                          if (model.failed) ...[
                            const SizedBox(height: 14),
                            _Banner(
                              text: 'Something went wrong here.',
                              color: colors.warn,
                              background: colors.warnSoft,
                            ),
                          ],
                          const SizedBox(height: 16),
                          const _Label('Subject'),
                          if (scope.config.requestSubjects case final subjects
                              when subjects.isNotEmpty)
                            _SubjectField(
                              key: const Key('subject'),
                              controller: _subject,
                              subjects: subjects,
                            )
                          else
                            _Field(
                              key: const Key('subject'),
                              controller: _subject,
                              hint: _subjectHint,
                            ),
                          if (extra != null) ...[
                            const SizedBox(height: 12),
                            _Label(extra.label, optional: true),
                            _Field(
                              key: const Key('extra'),
                              controller: _extra,
                              hint: extra.hint,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const _Label('Message'),
                          _Field(
                            key: const Key('message'),
                            controller: _message,
                            hint: 'Tell us more about your inquiry…',
                            lines: 4,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: ready ? _send : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Send'),
                          ),
                        ],
                      );
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

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (optional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.rule.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OPTIONAL',
                style: TextStyle(
                  color: colors.ink2,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _subjectHint = 'What can we help you with?';

/// The form's own look for a text box.
InputDecoration _decoration(SupportColors colors, String? hint) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.ink3, fontSize: 13.5),
      filled: true,
      fillColor: colors.shelf,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    this.hint,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String? hint;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 8,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(color: colors.ink, fontSize: 14),
      decoration: _decoration(colors, hint),
    );
  }
}

/// Subject with the brand's subjects to pick from, filtered as the customer types; their
/// own words are as welcome.
class _SubjectField extends StatelessWidget {
  const _SubjectField({
    super.key,
    required this.controller,
    required this.subjects,
  });

  final TextEditingController controller;
  final List<RequestSubject> subjects;

  static const _menuHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    // Focusing the box scrolls the form up by the list's height, so the keyboard the
    // customer types into leaves the whole list in view.
    final listRoom = math.min(16 + 48.0 * subjects.length, _menuHeight) + 20;
    return DropdownMenu<String>(
      controller: controller,
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      menuHeight: _menuHeight,
      scrollPadding: EdgeInsets.fromLTRB(20, 20, 20, listRoom),
      textStyle: TextStyle(color: colors.ink, fontSize: 14),
      // A plain arrow rather than the default button, so the box keeps the form's height.
      decorationBuilder: (context, menu) =>
          _decoration(colors, _subjectHint).copyWith(
            suffixIcon: Icon(
              menu.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: colors.ink3,
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.paper),
      ),
      dropdownMenuEntries: [
        for (final subject in subjects)
          DropdownMenuEntry(value: subject.key, label: subject.label),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bolt_rounded, size: 18, color: colors.onAccent),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.ink2, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
