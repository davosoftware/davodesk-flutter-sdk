/// DavoDesk support inside a Flutter app: the customer's conversations, help articles and
/// live chat with the support team. See the README.
library;

export 'src/client.dart';
export 'src/data/repositories/chat_repository.dart';
export 'src/data/repositories/session_repository.dart';
export 'src/data/services/api_service.dart'
    show DavoDeskApi, DavoDeskApiError, UploadFile;
export 'src/data/services/chat_socket.dart' show ChatSocket, ChatSocketFactory;
export 'src/domain/chat_events.dart';
export 'src/domain/conversation.dart' show Conversation;
export 'src/domain/models.dart';
