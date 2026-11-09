# Host API

The example app's pretend company backend. It will sign DavoDesk identity tokens for the
app's pretend customers, the way a real company's server does, so the signing secret never
goes into the app.

```bash
dart run bin/server.dart     # listens on PORT, 8787 by default
dart test
```
