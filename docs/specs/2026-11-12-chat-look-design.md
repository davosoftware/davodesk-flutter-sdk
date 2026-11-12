# Chat look: a brand's chat, set in one place and seen as you set it

**Status:** design, awaiting the owner's approval (2026-11-12).
**Touches:** DavoDesk (`apps/app`), the API (`apps/api`), the web widget (`apps/widget`) and
the Flutter SDK (its own repo, `davodesk-flutter-sdk`).
**Mockup:** [`2026-11-12-chat-look-mockup.html`](2026-11-12-chat-look-mockup.html): v7, the
layout the owner approved (v5) with the app's own colour (v6) and corners (v7) added. Open it in a browser; its
yellow bar is the mockup's, not the design's.

## Why

A brand wants its chat to feel like its own. Today the bot's replies are bare bubbles: on
the website a small "DavoDesk AI" tag sits on answers the AI wrote, and greetings and FAQ
answers carry nothing; in the app every bot reply carries the bot's name but no logo.
Nothing says "this is Davochain talking".

The settings that shape the chat are also spread over four places: the logo panel, the
**Your website** and **Your app** steps (colour, launcher, title, links), the app's chat
screen settings (tagline, notice), and **DavoDesk AI for this brand** (the bot's name). An
admin changes one, then has to open their own site or app to see what it did.

## What the owner decided (2026-11-12)

1. The bot's replies show the brand's logo and the bot's name, for example
   "Davochain bot".
2. The name is whatever the brand sets. DavoDesk never makes one up from the brand's name
   ("<brand> bot").
3. Admins get a live preview of the chat that switches between the website widget and the
   app (Flutter SDK), and shows a new logo or bot name at once.
4. The preview is for desktop only, not phones or small screens.
5. The preview always shows whole: nobody scrolls to see the rest of it (mockup v5).
6. A brand's website and its app may have different colours (mockup v6).
7. Corners, rounded or square, are set in DavoDesk too, even though an app's code can
   already set them (mockup v7).

## Calls I made (the owner may overturn any of them)

- **One page, "Chat look", per brand** holds every look setting. Each setting's old place
  keeps a link to it, so no setting can be changed in two places.
- **The preview sits on the right**, as in the approved mockup. The owner first suggested
  the left; the right keeps edit, then result, in reading order, beside DavoDesk's own menu
  on the left, and matches where a launcher sits on most websites.
- **The default name stays "DavoDesk AI"** while a brand has set none, as today.
- **✦ marks what the AI wrote.** FAQ answers and greetings were written by people, so they
  don't carry it. The mark also tells customers they are reading a machine's answer, which
  rules such as the EU AI Act expect.
- **The logo and name show once per run** of the bot's bubbles, as chat apps do.
- **The app's colour, corners and home links start as "Same as website"**, so a brand
  enters them once; unticking gives the app its own. The owner asked for separate colours;
  corners and links follow the same pattern because they too are stored per channel.
- **Square means no rounding at all**, on every chat surface: the panel, the launcher, the
  bubbles, the buttons, the fields and the logo's tile. That is what the SDK's square
  already means.
- **A website's look is set in DavoDesk only**: the widget takes no look options in code,
  so the preview is always right. An app's code may still set its colours and fonts.
- **The SDK re-reads the look each time support opens**, so a change saved in DavoDesk
  reaches the app without a restart or a new release.
- **The website preview runs the widget's own code**, so it cannot drift from the real
  widget. The app preview is a drawing, because Flutter cannot run inside DavoDesk.
- **One Save for the page; nothing goes live before it**, logos included.
- **The API says which bot messages the AI wrote**, so the widget and the SDK never guess.

## Goals

- An admin sets the logo, the bot's name, the colour and the rest on one page, and sees
  each change in the preview as they type, before saving.
- After Save, the real widget and the real app look as the preview showed.
- The bot's replies show who is speaking, in both the widget and the SDK, the same way.

## Non-goals

- No preview on phones or small screens.
- No look options in the widget's code: a website's look lives in DavoDesk.
- No change to how human agents appear: they keep their names, with no logo.
- No fonts set from DavoDesk: an app's fonts stay in its own code (the SDK's theming).
- "Powered by DavoDesk" stays as it is; it is not a setting.

## Anti-goals: it fails even if it works when

- The preview shows something the real chat does not.
- A half-saved page leaves the widget showing a mix of old and new settings without saying
  so.
- The bot's name ends up hardcoded anywhere in the widget or the SDK.

## The page

**Where:** its own page under **Brands → the brand**, reached from the brand's setup page
like the other steps. Its summary there reads like "Logo set. Bot: Davochain bot." It never
shows as to do: every setting has a default.

**Who:** whoever can change the brand's settings today. Anyone else does not see the page
or its entry, rather than seeing it disabled.

**Layout** (mockup v5): the page fills the window and does not scroll. On the left, the
title and the settings, which scroll on their own, with the save bar always at their
bottom. On the right, the preview, the full height of the page.

**The settings, in order:**

| Card | Field | Stored on | Notes |
|---|---|---|---|
| Logo | Logo | the brand (`logo_key`) | Shown in the header and on the bot's replies. Resized to 256 px by the API, as today. |
| Logo | Header logo (apps only) | the brand (`header_logo_key`) | The wordmark for the app's coloured header. |
| Logo | Title | both channels' `appearance.title` | The name in the chat's header. Empty means the brand's name. |
| Bot | Bot's name | the brand's AI settings (`ai.agent_name`) | Empty means "DavoDesk AI". |
| On your website | Colour | the website channel's `appearance.accent_color` | Launcher, buttons, the customer's own messages. |
| On your website | Corners | the website channel's `appearance.corners` (new) | Rounded (the default) or square. |
| On your website | Launcher side, launcher label | the website channel's `appearance` | The label is the launcher's name for screen readers and its hover text. |
| On your website | Home screen links | the website channel's `appearance.home_links` | Up to five, as today. |
| In your app | Colour | the app channel's `appearance.accent_color` | "Same as website" ticked writes the website's colour here too. The app's own code may set its own. |
| In your app | Corners | the app channel's `appearance.corners` (new) | "Same as website" as for colour. The app's own code may set its own. |
| In your app | Home screen links | the app channel's `appearance.home_links` | "Same as website" ticked writes the website's links here too. |
| In your app | Tagline, notice | the brand (`tagline`, `chat_notice`) | Lines under the header logo and above the chat. |

A brand with only a website shows no "In your app" card and no App view; a brand with only
an app shows no "On your website" card and no Website view, and its colour and links have no
"Same as website". A brand with neither sees one line pointing to **Where customers reach
you**.

"Same as website" starts ticked only when the app's stored value equals the website's.

`appearance.corners` is the one new setting: the API accepts it on both kinds of channel
and sends it in the channel's public settings, which the widget and the SDK already read.

**Saving:** one Save sends every changed setting through the endpoints DavoDesk uses today.
A logo picked but not saved shows in the preview from the file itself, and is uploaded on
Save. When one part fails, the parts that saved stay saved, and the failed field says why
("Saved, except the logo: use an image up to 1 MB"). Leaving the page with unsaved changes
asks first.

**Old places:** the logo panel, the Look sections of **Your website** and **Your app**, the
chat screen settings and the bot's name on **DavoDesk AI for this brand** are replaced by
one line each linking to Chat look. The rest of those steps (channel id, allowed sites,
visitors, install, privacy notice, the AI's other settings) stays where it is.

## The preview

- **Switch:** Website | App, above the preview, offering only the views the brand has.
- **Live:** it follows the form's unsaved values, as the admin types.
- **Whole:** its content is drawn at full size and scaled down to fit the column's height,
  never cropped and never scrolled. At 1280 × 620 it shows at about 60%, at 1366 × 768
  about 85%, and full size from 1440 × 900.
- **Desktop only:** below 1280 px of window width the preview is hidden and the settings
  take the whole page.
- **Sample conversation:** a greeting, a customer's question, an answer the AI wrote with a
  source, and "Did this solve it?". The customer is called Chidi.
- **Website view:** the widget's own panel and launcher on a plain page standing for the
  brand's website. It runs the widget's real code in a preview mode that makes no network
  calls and opens no session; DavoDesk hands it the unsaved look.
- **App view:** a drawing of the SDK's chat screen in a phone: the coloured header with the
  header logo (or the brand's name), the tagline, the notice, the bubbles, the composer and
  "Powered by DavoDesk". A line below it says the app's developers can change its colours
  and fonts in code, so the preview shows DavoDesk's settings, not their code's. The drawing
  follows what the SDK really shows: whether its screens use the channel's title is for
  the builder to check in the SDK before drawing it.

## The bot's bubbles (widget and SDK)

- The first bubble of each run shows, above it: the brand's logo as a small tile, the bot's
  name, and ✦ when the AI wrote the run.
- A run is a row of the bot's messages of one kind, AI-written or not. Any other message, a
  system line ("Ada joined") or a change of kind starts a new run.
- A brand without a logo shows its first letter on its colour, in the tile.
- The name is the brand's bot name, or "DavoDesk AI" while it has none. The widget's
  hardcoded "DavoDesk AI" tag goes.
- Customers' bubbles and human agents' bubbles do not change.

**The API:** every bot message says whether the AI wrote it (a boolean on the message, in
both the history and the live events). Messages stored before this change answer the way
the widget guesses today: true when a source scores below 1, or when the message asks "Did
this solve it?". Both clients take ✦ from that field alone.

## Where the look comes from

Developers write no code for any of this: the widget and the SDK read the look from
DavoDesk.

| | Website widget | App (Flutter SDK) |
|---|---|---|
| Logo, header logo, title, bot's name, tagline, notice, links | DavoDesk | DavoDesk |
| Colour | DavoDesk | the app's code if it sets one (`DavoDeskTheme`), else DavoDesk |
| Corners | DavoDesk | the app's code if it sets them (`DavoDeskTheme.corners`), else DavoDesk |
| Fonts, background and text colours | the widget's own | the app's code if it sets them, else the SDK's own |
| A change saved in DavoDesk shows | on the next page load | the next time support opens (today: the next app start) |

## Constraints

- DavoDesk: every control from its `src/components/ui` (shadcn and Radix); it must look right
  in its light and its near-black dark theme.
- The widget's loader stays under its 10 KB budget: the preview mode belongs to the frame,
  not the loader.
- The website preview is served from the widget's address, so nginx there and DavoDesk's
  own security policy must allow DavoDesk to frame it. DEPLOY_VPS.md says how.
- The SDK ships from its own repo, maybe before or after the API, and the widget may deploy
  before the API does. A client that gets no AI field in a message shows no ✦ rather than
  guessing.

## Left to the builder

Routes and components, the field's name in the API, how DavoDesk talks to the preview
frame, the scaling math, the order the parts ship in, and the tests and screenshots that
prove them.

## Done looks like

- Typing a bot name changes every bot reply in the preview at once; after Save, the real
  widget and app show it.
- Removing the logo shows the brand's first letter in the preview, and after Save in the
  real chat.
- In both clients, the bot's replies show the logo and name once per run, with ✦ only on
  runs the AI wrote.
- At 1280 × 620 the page does not scroll and the whole preview shows; below 1280 px wide,
  there is no preview.
- With "Same as website" unticked, a different app colour shows in the App view only, and
  after Save in the app, unless the app's code sets its own colour.
- Square corners on the website square the whole widget in the preview and, after Save, on
  the site; the app follows while "Same as website" is ticked, unless its code sets corners.
- A change saved in DavoDesk shows in an open app the next time its support screen opens.
- No look setting can be changed in two places.
