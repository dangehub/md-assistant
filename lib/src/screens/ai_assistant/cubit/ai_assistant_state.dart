//part of 'ai_assistant_cubit.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:obsi/src/core/tasks/task.dart';

sealed class AIAssistantState {}

class AIAssistantMessages extends AIAssistantState {
  List<types.Message> messages = [];
  List<Task> tasks = [];

  int _counter = 0;
  bool showReasoning;
  bool alwaysAllowTools;
  static const user = types.User(
    firstName: "User",
    id: 'baeb2c47-c0ea-468e-b6a5-563341f995e3',
  );
  static const aiUser = types.User(
    firstName: "VaultMate",
    id: 'af25d069-4513-4724-a0f2-d4fba793c356',
  );
  types.User? typingUser;

  AIAssistantMessages.init()
      : showReasoning = true,
        alwaysAllowTools = false;

  AIAssistantMessages(AIAssistantMessages prevMessage)
      : messages = prevMessage.messages,
        _counter = prevMessage._counter,
        showReasoning = prevMessage.showReasoning,
        alwaysAllowTools = prevMessage.alwaysAllowTools;

  void addRequest(String message) {
    _counter++;
    messages.insert(
        0,
        types.TextMessage(
          author: user,
          id: _counter.toString(),
          text: message,
        ));
  }

  void addCustomResponse(List<dynamic> response, String type) {
    _counter++;
    messages.insert(
        0,
        types.CustomMessage(
            author: aiUser,
            id: _counter.toString(),
            metadata: {'response': response, 'type': type}));
  }

  void clear() => messages.clear();

  void resetCounter() => _counter = 0;
}

class AIAssistantMessagesWithError extends AIAssistantMessages {
  String error;
  AIAssistantMessagesWithError(super.prevMessage, this.error);
}
