# DavoDesk for Flutter

Three separate projects, each with its own dependencies, tests and README:

| Folder | What it is | Who uses it |
|---|---|---|
| [`davodesk_flutter/`](davodesk_flutter/) | The SDK: a Flutter package with DavoDesk's support screens and the client under them | App developers add it to their app |
| [`example_app/`](example_app/) | A pretend company app ("Acme") that uses the SDK | Us, to try the SDK on a phone or emulator |
| [`host_api/`](host_api/) | The pretend company's backend: it signs identity tokens | The example app, as a real app uses its own server |

How they fit together:

```
example_app ──(1) "who is signed in?"──> host_api        holds the signing secret
example_app <──(2) identity token ─────── host_api
example_app ──(3) open a session with the token, chat, tickets, help ──> DavoDesk API
```

The signing secret stays on the server. A mobile app never holds it.

The SDK is optional: everything it does goes through the public DavoDesk API, which a
developer can call directly instead (`apps/api/docs/HOST_APP_INTEGRATION.md` in the
davodesk-apps repo).

The screens can take the app's own look: its colours for light and dark, its fonts and
square or rounded corners (`DavoDeskTheme`, in the SDK's README under "The look").

The design is in [`docs/specs/`](docs/specs/).
