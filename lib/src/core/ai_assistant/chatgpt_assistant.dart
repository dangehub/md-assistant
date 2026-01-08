import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:obsi/src/core/ai_assistant/action.dart';
import 'package:obsi/src/core/ai_assistant/ai_assistant.dart';
import 'package:openai_dart/openai_dart.dart';

class ChatGptAssistant extends AIAssistant {
  final Map<int, Completer<bool>> _pendingConfirmations = {};

  ChatGptAssistant(super.apiKey, super.toolsRegistry,
      {super.baseUrl, super.modelName});

  @override
  void reInitialize(String apiKey, {String? baseUrl, String? modelName}) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.modelName = modelName;
  }

  @override
  Future<String?> chat(List<ChatCompletionMessage> messages,
      String currentDateTime, String vault) async {
    final client = OpenAIClient(
      apiKey: apiKey ?? "",
      baseUrl: baseUrl?.isNotEmpty == true ? baseUrl : null,
    );

    // Prepare prompt with tools
    var toolsInfo = toolsRegistry.getFunctionInfos();
    String toolsDesc = toolsInfo.join("\n");

    // Create a new list to avoid modifying the original list in place repeatedly (if passed by ref)
    List<ChatCompletionMessage> conversation = List.from(messages);

    // Add System Prompt
    conversation = addSystemPrompt(conversation, currentDateTime);

    // Inject Tools Description into the System Prompt or as a separate System Prompt
    // Since addSystemPrompt adds it at index 0, we can update index 0 or insert after.
    // Let's modify the first message if it is system, or insert new one.

    // For OpenAI compatible with tool prompt hacking (JSON mode):
    String toolInstruction = """
\n
You have access to the following tools:
$toolsDesc

Refuse to use tools that are not in the list.
Response Format: You MUST respond in JSON format with the following structure:
{
  "thought": "your reasoning here",
  "actions": [
    {"id": 123, "name": "tool_name", "parameters": ["arg1", "arg2"]}
  ],
  "final_answer": "your final answer to the user (if no actions needed)"
}
If no actions are needed, set "actions" to an empty array [] and provide "final_answer".
If performing actions, "final_answer" should be null or empty string until the actions are completed and you have the result.
""";

    if (conversation.isNotEmpty &&
        conversation.first is ChatCompletionSystemMessage) {
      var sysMsg = conversation.first as ChatCompletionSystemMessage;
      conversation[0] = ChatCompletionMessage.system(
          content: sysMsg.content + toolInstruction);
    } else {
      conversation.insert(
          0, ChatCompletionMessage.system(content: toolInstruction));
    }

    // ReAct Loop
    int maxAttempts = 5;
    ResponseWithAction? responseWithAction;

    while (maxAttempts > 0) {
      maxAttempts--;

      // Call OpenAI
      // Ensure we use JSON mode if possible
      CreateChatCompletionResponse res;
      try {
        res = await client.createChatCompletion(
            request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(modelName ?? 'gpt-3.5-turbo'),
          messages: conversation,
          temperature: 0.3,
        ));
      } catch (e) {
        Logger().e("OpenAI Chat Error: $e");
        // Fallback: try without json_mode if it failed?
        // Or just rethrow.
        // Better wrap in try-catch to provide user feedback.
        return "Error calling AI: $e";
      }

      var content = res.choices.first.message.content;
      if (content == null || content.isEmpty) {
        return "Error: Empty response from AI.";
      }

      Logger().i("AI Response: $content");

      // Parse JSON
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;
        responseWithAction = ResponseWithAction.fromJson(json);
      } catch (e) {
        Logger().e("JSON Parse Error: $e");
        // If parsing fails, maybe model didn't output JSON.
        // Treat raw content as answer?
        return content;
      }

      // Emit thought
      emitMessage(AIMessage.reasoning(responseWithAction.thought));

      // Execute Actions
      if (responseWithAction.actions != null &&
          responseWithAction.actions!.isNotEmpty) {
        var toolResultBuffer = StringBuffer();
        for (var action in responseWithAction.actions!) {
          var toolOutput = await _executeAction(action);
          toolResultBuffer.writeln(toolOutput);
        }

        // Append Tool Output to Conversation
        // We simulate this as a User Message observing the output
        conversation.add(ChatCompletionMessage.assistant(
            content: content)); // Add the AI's JSON response
        conversation.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
                "Observation:\n${toolResultBuffer.toString()}")));

        // Continue loop
      } else {
        // No actions, return final answer
        if (responseWithAction.finalAnswer != null) {
          emitMessage(AIMessage.text(responseWithAction.finalAnswer!));
          return responseWithAction.finalAnswer;
        } else {
          // Should not happen if schema is followed
          return "No answer provided.";
        }
      }
    }

    return "Max attempts reached.";
  }

  Future<String> _executeAction(Action action) async {
    var functionName = action.name;
    var parameters = action.parameters;
    var toolResult = "";

    if (toolsRegistry.functionExists(functionName)) {
      var res = "";
      try {
        if (toolsRegistry.requiresConfirmation(functionName)) {
          var completer = Completer<bool>();
          _pendingConfirmations[action.id] = completer;

          emitMessage(AIMessage.toolConfirmation({
            'actionId': action.id,
            'name': functionName,
            'parameters': parameters,
            'description': toolsRegistry.getDescription(functionName),
          }));

          var allowed = await completer.future;
          _pendingConfirmations.remove(action.id);

          if (!allowed) {
            return "$functionName(${parameters.join(", ")}) was declined by user.\n";
          }
        }

        Logger()
            .i("Calling function $functionName with parameters $parameters");
        res = await toolsRegistry.callFunction(functionName, parameters);
      } catch (e) {
        Logger().e("Error calling function $functionName: $e");
        res = "Error: $e";
      }

      toolResult = "$functionName(${parameters.join(", ")}) produced: $res\n";
    } else {
      toolResult =
          "$functionName(${parameters.join(", ")}) is not registered\n";
    }
    return toolResult;
  }

  @override
  Future<void> confirmToolAction(int actionId, bool allowed) async {
    var completer = _pendingConfirmations[actionId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(allowed);
    } else {
      Logger().w('No pending confirmation for actionId $actionId');
    }
  }
}

class ResponseWithAction {
  final String thought;
  final List<Action>? actions;
  final String? finalAnswer;

  ResponseWithAction({
    required this.thought,
    this.actions,
    this.finalAnswer,
  });

  factory ResponseWithAction.fromJson(Map<String, dynamic> json) {
    // Validate required field
    if (!json.containsKey('thought')) {
      // Be lenient?
    }

    final actions = (json['actions'] as List<dynamic>?)
        ?.map((action) => Action.fromJson(action as Map<String, dynamic>))
        .toList();

    return ResponseWithAction(
      thought: json['thought'] as String? ?? "",
      actions: actions,
      finalAnswer: json['final_answer'] as String?,
    );
  }
}
