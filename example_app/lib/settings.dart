import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'acme.host_api';

/// Where the example's host API runs: the computer as the Android emulator sees it,
/// or as the iOS simulator does.
String get defaultHostApi => defaultTargetPlatform == TargetPlatform.iOS
    ? 'http://localhost:8787'
    : 'http://10.0.2.2:8787';

/// The host API's address, kept on the device so a phone can point at the computer.
class HostSettings {
  final _preferences = SharedPreferencesAsync();

  /// The address saved last, or the default.
  Future<String> load() async =>
      await _preferences.getString(_key) ?? defaultHostApi;

  /// Keeps [address] for next time.
  Future<void> save(String address) => _preferences.setString(_key, address);
}
