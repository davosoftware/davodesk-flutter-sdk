# Host API

The example app's pretend company backend. It signs DavoDesk identity tokens for the app's
pretend customers (Ada Lovelace and Ben Okafor), the way a real company's server does, so
the signing secret never goes into the app.

```bash
cp .env.example .env         # then fill in the channel id and signing key from DavoDesk
dart run bin/server.dart     # listens on PORT, 8787 by default, on all interfaces
dart test
```

| Route | What it does |
|---|---|
| `GET /health` | `{ "ok": true }` |
| `GET /app-config` | `{ api_url, channel_id }`, so the app is set up in one place |
| `POST /login { "customer": "ada" \| "ben" }` | `{ token, name }`: pretend sign-in, no password |
| `GET /support/identity` (bearer: that token) | `{ identity_token }`: HS256, `kid` in the header, five minutes |

The Android emulator reaches this server at `http://10.0.2.2:8787`. It never prints the
secret or a token.
