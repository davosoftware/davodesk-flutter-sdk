import '../domain/models.dart';

/// A ticket's reference: `#` and the last six characters of its id, upper-cased, as the
/// web widget writes it.
String referenceOf(String id) =>
    '#${(id.length > 6 ? id.substring(id.length - 6) : id).toUpperCase()}';

/// The name a person on the team goes by when they have none.
String teamName(String brand) => '$brand team';

/// The first word of [name], or null without one.
String? firstNameOf(String? name) {
  final words = name?.trim().split(RegExp(r'\s+')) ?? const [];
  return words.isEmpty || words.first.isEmpty ? null : words.first;
}

/// Who wrote a message: "You", the AI's name, the person's name, or the brand's team,
/// never "Staff".
String speakerName(
  SenderType type,
  String? displayName, {
  required String brand,
  required String aiName,
}) => switch (type) {
  .endUser => 'You',
  .bot => aiName,
  .staff when displayName != null && displayName.trim().isNotEmpty =>
    displayName.trim(),
  _ => teamName(brand),
};
