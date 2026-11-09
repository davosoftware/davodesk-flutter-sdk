/// The support screens in Flutter's Widget Previewer, light and dark, fed by fixtures.
library;

import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import 'core/support_shell.dart';
import 'theme.dart';
import 'widgets/brand_tile.dart';
import 'widgets/header_logo.dart';
import 'widgets/powered_by.dart';
import 'widgets/recover.dart';
import 'widgets/state_chip.dart';

Widget _onPage(Brightness brightness, Widget child) => SupportShell(
  colors: SupportColors.from(accent: defaultAccent, brightness: brightness),
  child: Builder(
    builder: (context) => ColoredBox(
      color: SupportColors.of(context).shelf,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

Widget _pieces(Brightness brightness) => _onPage(
  brightness,
  Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      const HeaderLogo(url: null, name: 'Davopay'),
      const Row(
        spacing: 8,
        children: [
          BrandTile(logoUrl: null, name: 'Davopay'),
          BrandTile(logoUrl: null, name: 'Acme', size: 32),
        ],
      ),
      const Wrap(
        spacing: 6,
        children: [
          StateChip(status: 'open'),
          StateChip(status: 'pending'),
          StateChip(status: 'resolved'),
          StateChip(status: 'closed'),
        ],
      ),
      Recover(onRetry: () {}),
      const PoweredBy(),
    ],
  ),
);

/// The shared pieces, light.
@Preview(group: 'Pieces', name: 'Light')
Widget piecesLight() => _pieces(Brightness.light);

/// The shared pieces, dark.
@Preview(group: 'Pieces', name: 'Dark')
Widget piecesDark() => _pieces(Brightness.dark);
