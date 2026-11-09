import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';

import '../services/api_service.dart';

final _log = Logger('DavoDesk');

/// Where the customer's session stands.
sealed class SessionState {
  /// Creates a state.
  const SessionState();
}

/// No session yet, or after logging out.
final class SessionIdle extends SessionState {
  /// Creates the idle state.
  const SessionIdle();
}

/// A session is being opened.
final class SessionOpening extends SessionState {
  /// Creates the opening state.
  const SessionOpening();
}

/// A session is open: [token] authorises the customer's calls until [expiresAt].
final class SessionReady extends SessionState {
  /// Creates the ready state.
  const SessionReady({
    required this.token,
    required this.brandId,
    required this.expiresAt,
    this.name,
  });

  /// The session token, kept in memory only.
  final String token;

  /// The brand the channel belongs to.
  final String brandId;

  /// The customer's name, from the identity token.
  final String? name;

  /// When the session runs out.
  final DateTime expiresAt;
}

/// No session for now; it retries by itself. [code] is `TOKEN_FAILED` (the app's backend
/// gave no usable identity token) or `CHANNEL_UNAVAILABLE`.
final class SessionUnavailable extends SessionState {
  /// Creates the unavailable state.
  const SessionUnavailable(this.code);

  /// Why there is no session.
  final String code;
}

/// Too many sessions were opened; it retries after [retryAfter] seconds.
final class SessionLimited extends SessionState {
  /// Creates the limited state.
  const SessionLimited(this.retryAfter);

  /// Seconds the API asked to wait.
  final int? retryAfter;
}

/// The integration guide's backoff (§4): exponential with jitter, capped at five minutes.
Duration backoff(int attempt, double random) => Duration(
  milliseconds: (min(300000, 1000 * pow(2, attempt)) * (0.5 + random / 2))
      .round(),
);

/// Renew this long before the session runs out.
const _renewEarly = Duration(minutes: 1);

class _TokenFailed implements Exception {}

/// The customer's session (the integration guide, §2 and §10).
///
/// It asks the app's backend for an identity token through [identityToken] each time it
/// opens one, keeps the session token in memory only, renews a minute before it runs out,
/// and retries with a growing wait when the token or the channel can't serve.
class DavoDeskSession {
  /// Creates a session for `channelId`, opened through `api`.
  ///
  /// The private named parameters (Dart 3.12) are passed as `api:`, `channelId:` and
  /// `identityToken:`.
  DavoDeskSession({
    required this._api,
    required this._channelId,
    required this._identityToken,
    double Function()? random,
  }) : _random = random ?? Random().nextDouble;

  final DavoDeskApi _api;
  final String _channelId;
  final Future<String?> Function() _identityToken;
  final double Function() _random;
  final _states = StreamController<SessionState>.broadcast();

  SessionState _state = const SessionIdle();
  Future<SessionState>? _inFlight;
  Timer? _timer;
  int _attempt = 0;
  String? _subject;

  /// Where the session stands now.
  SessionState get state => _state;

  /// Every change of state.
  Stream<SessionState> get states => _states.stream;

  /// The `sub` of the last identity token, read without trusting it: it keys what the
  /// device remembers for this customer.
  String? get subject => _subject;

  /// The open session, opening one if there is none.
  ///
  /// Callers at the same time share one open, and a retry already waiting is left to run.
  Future<SessionState> ensure() {
    if (_inFlight case final open?) return open;
    if (_state is SessionReady || _timer != null) return Future.value(_state);
    return _open();
  }

  /// Opens a fresh session now: after a `401`, or the socket's `UNAUTHENTICATED`.
  Future<SessionState> renew() => _open();

  /// Ends the session at the API and on the device.
  Future<void> logout() async {
    _cancel();
    if (_state case SessionReady(:final token)) {
      try {
        await _api.logout(token);
      } on Object catch (error) {
        _log.fine('Logout did not reach the API: $error');
      }
    }
    _attempt = 0;
    _subject = null;
    _set(const SessionIdle());
  }

  /// Stops renewing and retrying.
  void dispose() {
    _cancel();
    _states.close();
  }

  Future<SessionState> _open() {
    if (_inFlight case final open?) return open;
    _cancel();
    return _inFlight = _attemptOpen().whenComplete(() => _inFlight = null);
  }

  Future<SessionState> _attemptOpen() async {
    _set(const SessionOpening());
    try {
      final identity = await _identityToken().catchError((Object _) => null);
      if (identity == null || identity.isEmpty) throw _TokenFailed();
      _subject = _subjectOf(identity);
      final opened = await _api.openSession(
        channelId: _channelId,
        identityToken: identity,
      );
      _attempt = 0;
      final renewIn = opened.expiresIn - _renewEarly;
      _later(renewIn.isNegative ? Duration.zero : renewIn);
      return _set(
        SessionReady(
          token: opened.sessionToken,
          brandId: opened.brandId,
          name: opened.customerName,
          expiresAt: DateTime.now().add(opened.expiresIn),
        ),
      );
    } on Object catch (error) {
      return _refuse(error);
    }
  }

  SessionState _refuse(Object error) {
    switch (error) {
      case _TokenFailed():
      case DavoDeskApiError(
        code: 'INVALID_IDENTITY_TOKEN' || 'IDENTITY_EMAIL_CONFLICT',
      ):
        _retry();
        return _set(const SessionUnavailable('TOKEN_FAILED'));
      case DavoDeskApiError(status: 429, :final retryAfter):
        _retry(retryAfter);
        return _set(SessionLimited(retryAfter));
      default:
        _log.fine('The session could not open: $error');
        _retry();
        return _set(const SessionUnavailable('CHANNEL_UNAVAILABLE'));
    }
  }

  void _retry([int? retryAfter]) {
    _later(
      retryAfter != null
          ? Duration(seconds: retryAfter)
          : backoff(_attempt, _random()),
    );
    _attempt++;
  }

  void _later(Duration wait) {
    _cancel();
    _timer = Timer(wait, () {
      _timer = null;
      _open();
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  SessionState _set(SessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
    return next;
  }

  static String? _subjectOf(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, Object?> && payload['sub'] is String
          ? payload['sub']! as String
          : null;
    } on FormatException {
      return null;
    }
  }
}
