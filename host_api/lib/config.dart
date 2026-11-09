import 'dart:io';

/// The host API's settings, from `host_api/.env` and the environment.
class const HostConfig({
  required final String apiUrl,
  required final String channelId,
  required final String signingKeyId,
  required final String signingSecret,
  final int port = 8787,
}) {
  /// Reads the settings from [env], naming any missing key and never a value.
  factory fromEnv(Map<String, String> env) {
    const keys = [
      'DAVODESK_API_URL',
      'DAVODESK_CHANNEL_ID',
      'DAVODESK_SIGNING_KEY_ID',
      'DAVODESK_SIGNING_SECRET',
    ];
    final missing = [
      for (final key in keys)
        if ((env[key] ?? '').isEmpty) key,
    ];
    if (missing.isNotEmpty) throw StateError('Missing: ${missing.join(', ')}');
    return HostConfig(
      apiUrl: env['DAVODESK_API_URL']!,
      channelId: env['DAVODESK_CHANNEL_ID']!,
      signingKeyId: env['DAVODESK_SIGNING_KEY_ID']!,
      signingSecret: env['DAVODESK_SIGNING_SECRET']!,
      port: int.tryParse(env['PORT'] ?? '') ?? 8787,
    );
  }
}

/// Reads `KEY=VALUE` lines from the file at [path], skipping blanks and `#` comments.
///
/// Returns an empty map when the file doesn't exist.
Map<String, String> readDotEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  return {
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty &&
          !line.trimLeft().startsWith('#') &&
          line.contains('='))
        line.substring(0, line.indexOf('=')).trim(): _unquoted(
          line.substring(line.indexOf('=') + 1).trim(),
        ),
  };
}

String _unquoted(String value) =>
    value.length >= 2 && (value.startsWith('"') && value.endsWith('"'))
    ? value.substring(1, value.length - 1)
    : value;
