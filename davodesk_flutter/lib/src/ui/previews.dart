/// The support screens in Flutter's Widget Previewer, light and dark, fed by fixtures.
library;

import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import 'core/support_shell.dart';
import 'features/conversation/conversation_page.dart';
import 'features/conversation/conversation_view_model.dart';
import 'features/home/home_page.dart';
import 'features/home/home_view_model.dart';
import 'features/messages/messages_page.dart';
import 'features/messages/messages_view_model.dart';
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

const _home = HomeState(
  brandName: 'Davopay',
  firstName: 'Chukwu',
  showHelp: true,
  recent: RecentCard(
    subject: 'Virtual card refund',
    line: 'Mara: The refund is back on your card',
    unread: true,
    ticketId: '6a0000000000009bbc55',
  ),
  links: [
    HomeLink('Explore Rewards: Key Details You Should Know', 'https://x.test'),
    HomeLink('Everything About Your Virtual Dollar Card', 'https://x.test'),
  ],
);

const _messages = MessagesState(
  rows: [
    MessageRow(
      id: '6a0000000000009bbc55',
      subject: 'Virtual card refund',
      status: 'pending',
      reference: '#9BBC55',
      line: 'Mara: The refund is back on your card',
      day: '9 Nov',
      unread: true,
    ),
    MessageRow(
      id: 'a00000000000a31f07',
      subject: 'Withdrawal to my bank account',
      status: 'resolved',
      reference: '#A31F07',
      line: 'You: Thanks, it arrived',
      day: '4 Nov',
    ),
  ],
);

Widget _screen(Brightness brightness, Widget child) => SupportShell(
  colors: SupportColors.from(
    accent: const Color(0xFF1E5AF0),
    brightness: brightness,
  ),
  child: child,
);

Widget _homeView(Brightness brightness) => _screen(
  brightness,
  HomeView(
    state: _home,
    onGo: (_) {},
    onLink: (_) {},
    onRetry: () {},
    onClose: () {},
  ),
);

Widget _messagesView(Brightness brightness, MessagesState state) => _screen(
  brightness,
  MessagesView(
    state: state,
    onOpen: (_) {},
    onAsk: () {},
    onNew: () {},
    onRetry: () {},
    onBack: () {},
  ),
);

const _joined = ConversationState(
  title: 'Mara',
  subtitle: 'Davopay team · #9BBC55',
  brandName: 'Davopay',
  tagline: 'Your global money partner',
  placeholder: 'Write a message…',
  canAttach: true,
  items: [
    BubbleItem(
      id: 'm1',
      text: 'My virtual card refund hasn’t come back',
      mine: true,
    ),
    BubbleItem(
      id: 'm2',
      text: 'I’ll pass you to the team, who can see your card’s history.',
      label: 'Callie',
      ai: true,
    ),
    JoinedItem('Mara'),
    BubbleItem(
      id: 'm3',
      text: 'Hi Chukwu, I can see it. It’s back on your card now.',
      label: 'Mara',
    ),
  ],
);

const _choosing = ConversationState(
  title: 'Callie',
  subtitle: 'The team can also help',
  brandName: 'Davopay',
  tagline: 'Your global money partner',
  notice:
      'We’re handling a high volume of requests, so replies may take a bit '
      'longer than usual. Thanks for your patience.',
  showComposer: false,
  items: [
    BubbleItem(
      id: 'm1',
      text:
          'Hello Chukwu 👋, this is Callie from Davopay. Please choose the '
          'option that best matches your request.',
      label: 'Callie',
      ai: true,
    ),
  ],
  choices: [
    ChatOption('t1', 'Account Management & Verification'),
    ChatOption('t2', 'Virtual Cards (Creation, Funding, Refunds)'),
    ChatOption('__else', 'Something Else'),
  ],
);

Widget _conversationView(Brightness brightness, ConversationState state) =>
    _screen(
      brightness,
      ConversationView(
        state: state,
        onSend: (_) {},
        onChoose: (_) {},
        onSolved: () {},
        onTalkToPerson: () {},
        onStartNew: () {},
        onAttach: (_) {},
        onOpenFile: (_) {},
        onRetry: () {},
        onBack: () {},
      ),
    );

/// A person joined, light.
@Preview(group: 'Conversation', name: 'Joined, light')
Widget conversationLight() => _conversationView(Brightness.light, _joined);

/// A person joined, dark.
@Preview(group: 'Conversation', name: 'Joined, dark')
Widget conversationDark() => _conversationView(Brightness.dark, _joined);

/// The FAQ's choices, with the notice.
@Preview(group: 'Conversation', name: 'Choices')
Widget conversationChoices() => _conversationView(Brightness.light, _choosing);

/// Home, light.
@Preview(group: 'Home', name: 'Light')
Widget homeLight() => _homeView(Brightness.light);

/// Home, dark.
@Preview(group: 'Home', name: 'Dark')
Widget homeDark() => _homeView(Brightness.dark);

/// Messages, light.
@Preview(group: 'Messages', name: 'Light')
Widget messagesLight() => _messagesView(Brightness.light, _messages);

/// Messages, dark.
@Preview(group: 'Messages', name: 'Dark')
Widget messagesDark() => _messagesView(Brightness.dark, _messages);

/// Messages with none yet.
@Preview(group: 'Messages', name: 'Empty')
Widget messagesEmpty() =>
    _messagesView(Brightness.light, const MessagesState());

/// The shared pieces, light.
@Preview(group: 'Pieces', name: 'Light')
Widget piecesLight() => _pieces(Brightness.light);

/// The shared pieces, dark.
@Preview(group: 'Pieces', name: 'Dark')
Widget piecesDark() => _pieces(Brightness.dark);
