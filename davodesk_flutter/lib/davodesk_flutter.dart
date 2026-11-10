/// DavoDesk support inside a Flutter app: the customer's conversations, help articles and
/// live chat with the support team. See the README.
library;

export 'src/client.dart';
export 'src/data/repositories/session_repository.dart'
    show
        SessionState,
        SessionIdle,
        SessionOpening,
        SessionReady,
        SessionUnavailable,
        SessionLimited;
export 'src/data/services/api_service.dart' show DavoDeskApiError, UploadFile;
export 'src/data/services/chat_socket.dart' show ChatSocket, ChatSocketFactory;
export 'src/davodesk.dart';
export 'src/domain/chat_events.dart' show ChatConnection;
export 'src/domain/conversation.dart' show Conversation;
export 'src/domain/models.dart';
export 'src/ui/theme.dart'
    show DavoDeskTheme, DavoDeskContactForm, DavoDeskFormField;
