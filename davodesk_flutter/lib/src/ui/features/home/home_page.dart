import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/scope.dart';
import '../../theme.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/powered_by.dart';
import '../../widgets/recover.dart';
import 'home_view_model.dart';

/// Home: the greeting, the conversation in progress, Messages, Help, Send us a
/// message, the channel's links, and Powered by DavoDesk.
class HomePage extends StatefulWidget {
  /// Creates Home.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model == null) {
      final scope = SupportScope.of(context);
      _model = HomeViewModel(scope.client, scope.config)..load();
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
      builder: (context, _) => HomeView(
        state: model.state,
        onGo: (place) => scope.go(context, place),
        onLink: (url) => scope.openLink(url),
        onRetry: model.load,
        onClose: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// Home drawn from [state].
class HomeView extends StatelessWidget {
  /// Creates the view.
  const HomeView({
    super.key,
    required this.state,
    required this.onGo,
    required this.onLink,
    required this.onRetry,
    required this.onClose,
  });

  /// What to show.
  final HomeState state;

  /// Leads to a place.
  final void Function(SupportPlace place) onGo;

  /// Opens a link.
  final void Function(Uri url) onLink;

  /// Loads again after a failure.
  final VoidCallback onRetry;

  /// Closes support.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final recent = state.recent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: colors.onAccent.computeLuminance() > 0.5
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.shelf,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top + 330,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.accent,
                      colors.accent,
                      Color.lerp(colors.accent, colors.shelf, 0.85)!,
                      colors.shelf,
                    ],
                    stops: const [0, 0.54, 0.76, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + 8,
                    ),
                    children: [
                      _Header(state: state, onClose: onClose),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          spacing: 12,
                          children: [
                            if (state.failed)
                              _Card(child: Recover(onRetry: onRetry)),
                            if (recent != null)
                              _Card(
                                child: _RecentRow(
                                  card: recent,
                                  onTap: () => onGo(switch (recent.ticketId) {
                                    final id? => TicketPlace(id),
                                    null => const ConversationPlace(),
                                  }),
                                ),
                              ),
                            if (state.showMessages || state.showHelp)
                              _Card(
                                child: Column(
                                  children: [
                                    if (state.showMessages)
                                      _Row(
                                        label: 'Messages',
                                        onTap: () =>
                                            onGo(const MessagesPlace()),
                                      ),
                                    if (state.showMessages && state.showHelp)
                                      const Divider(),
                                    if (state.showHelp)
                                      _Row(
                                        label: 'Help',
                                        onTap: () => onGo(const HelpPlace()),
                                      ),
                                  ],
                                ),
                              ),
                            if (state.showEmail)
                              _Card(
                                child: _Row(
                                  label: 'Send us a message',
                                  icon: Icons.send_rounded,
                                  onTap: () => onGo(const EmailPlace()),
                                ),
                              ),
                            if (state.links.isNotEmpty)
                              _Card(
                                child: Column(
                                  children: [
                                    for (final (i, link)
                                        in state.links.indexed) ...[
                                      if (i > 0) const Divider(),
                                      _Row(
                                        label: link.title,
                                        icon: Icons.open_in_new_rounded,
                                        small: true,
                                        onTap: () =>
                                            onLink(Uri.parse(link.url)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 20, bottom: 6),
                        child: Center(child: PoweredBy()),
                      ),
                    ],
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

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClose});

  final HomeState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final greeting = TextStyle(
      color: colors.onAccent,
      fontSize: 21,
      height: 1.3,
      fontWeight: FontWeight.w800,
    );
    final name = state.firstName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: HeaderLogo(
                  url: state.headerLogoUrl,
                  name: state.brandName,
                  color: colors.onAccent,
                ),
              ),
              IconButton(
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: colors.onAccent.withValues(alpha: 0.2),
                  foregroundColor: colors.onAccent,
                ),
                icon: const Icon(Icons.close_rounded, semanticLabel: 'Close'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            headingLevel: 1,
            child: Text(
              name == null ? 'Hi there 👋' : 'Hi $name 👋',
              style: greeting,
            ),
          ),
          Text('How can we help?', style: greeting),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    final dark = colors.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(16),
        border: dark ? Border.all(color: colors.rule) : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.icon = Icons.chevron_right_rounded,
    this.small = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: small ? 11 : 14,
          ),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: small ? 13 : 14.5,
                    fontWeight: small ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.card, required this.onTap});

  final RecentCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SupportColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    card.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (card.line.isNotEmpty)
                    Text(
                      card.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.ink2, fontSize: 13),
                    ),
                ],
              ),
            ),
            if (card.unread) _Dot(color: colors.accent),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.accent),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Unread',
    child: Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
