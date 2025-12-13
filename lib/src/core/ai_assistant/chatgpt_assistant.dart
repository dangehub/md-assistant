import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant.dart';
import 'package:obsi/src/core/ai_assistant/tools_registry.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatGptAssistant extends AIAssistant {
  ChatGptAssistant(String super.apiKey, ToolsRegistry super.toolsRegistry);

  @override
  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault) async {
    final client = OpenAIClient(apiKey: apiKey);

    List<ChatCompletionMessage> promptWithHistory =
        addSystemPrompt(messages, currentDateTime);

    final res = await client.createChatCompletion(
      request: CreateChatCompletionRequest(
        model: const ChatCompletionModel.modelId('gpt-4'),
        messages: promptWithHistory,
        temperature: 0.3,
      ),
    );

    return res.choices.first.message.content;
  }

  @override
  void reInitialize(String apiKey) {
    this.apiKey = apiKey;
  }

  @override
  Future<void> confirmToolAction(int actionId, bool allowed) async {
    // Tools with confirmation are not used in ChatGptAssistant for now.
  }

  Future<String?> sendPrompt(String question) {
    throw UnimplementedError(
        'sendPrompt is not implemented in ChatGptAssistant');
  }
}
