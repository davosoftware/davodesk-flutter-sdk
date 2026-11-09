import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client.dart';
import '../../data/services/api_service.dart';
import '../../domain/models.dart';
import '../theme.dart';

/// Where a support page can lead; the support routes decide how to get there.
sealed class SupportPlace {
  /// Creates a place.
  const SupportPlace();
}

/// The customer's conversations.
final class const MessagesPlace() extends SupportPlace {
  /// Creates the place.
  this;
}

/// The help centre.
final class const HelpPlace() extends SupportPlace {
  /// Creates the place.
  this;
}

/// The email form.
final class const EmailPlace() extends SupportPlace {
  /// Creates the place.
  this;
}

/// The live conversation; [fresh] starts a new one first.
final class const ConversationPlace({final bool fresh = false})
    extends SupportPlace {
  /// Creates the place.
  this;
}

/// One of the customer's tickets.
final class const TicketPlace(final String id) extends SupportPlace {
  /// Creates the place.
  this;
}

/// Where an attachment comes from.
enum AttachFrom {
  /// The phone's photos.
  photos,

  /// A file, such as a PDF.
  files,
}

/// What every support page reads: the [client], the channel's [config], how to [go]
/// elsewhere, how to [openLink], and the app's [emailForm].
class SupportScope extends InheritedWidget {
  /// Creates the scope.
  const SupportScope({
    super.key,
    required this.client,
    required this.config,
    required this.go,
    Future<bool> Function(Uri url)? openLink,
    Future<UploadFile?> Function(AttachFrom from)? pickAttachment,
    this.emailForm,
    required super.child,
  }) : openLink = openLink ?? _launch,
       pickAttachment = pickAttachment ?? _pick;

  /// The customer's client.
  final DavoDeskClient client;

  /// The channel's public settings.
  final ChannelConfig config;

  /// Leads to a place.
  final void Function(BuildContext context, SupportPlace place) go;

  /// Opens a web link outside the app.
  final Future<bool> Function(Uri url) openLink;

  /// Lets the customer pick a photo or a file; null when they cancel.
  final Future<UploadFile?> Function(AttachFrom from) pickAttachment;

  /// The email form's words that belong to the app.
  final DavoDeskEmailForm? emailForm;

  /// The scope around [context].
  static SupportScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SupportScope>();
    assert(scope != null, 'A support page is outside a SupportScope.');
    return scope!;
  }

  @override
  bool updateShouldNotify(SupportScope oldWidget) =>
      client != oldWidget.client ||
      config != oldWidget.config ||
      emailForm != oldWidget.emailForm;
}

Future<bool> _launch(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

Future<UploadFile?> _pick(AttachFrom from) async {
  final file = switch (from) {
    .photos => await ImagePicker().pickImage(source: ImageSource.gallery),
    .files => await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
          uniformTypeIdentifiers: ['com.adobe.pdf'],
        ),
      ],
    ),
  };
  if (file == null) return null;
  return UploadFile(
    file.name,
    await file.readAsBytes(),
    file.mimeType ?? contentTypeOf(file.name),
  );
}

/// The type a file's name suggests, for a picker that gives none.
String contentTypeOf(String name) =>
    switch (name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };

/// Whether a channel's link may be opened: http or https only, whatever its settings
/// hold (the web widget's rule).
bool isWebLink(String url) => switch (Uri.tryParse(url)) {
  final Uri uri =>
    (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty,
  null => false,
};
