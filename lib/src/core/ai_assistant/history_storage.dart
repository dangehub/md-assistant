import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as msg_types;
import 'package:logger/logger.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_state.dart';

class HistoryStorage {
  HistoryStorage(String historyFilePath) : _logFilePath = historyFilePath;

  final String _logFilePath;
  final bool _isLoggingEnabled = true;

  @visibleForTesting
  Map<String, dynamic>? parseLogEntry(String line) => _parseLogEntry(line);

  Future<void> appendMessageToLog(String messageText, bool isUser) async {
    if (!_isLoggingEnabled) {
      return;
    }

    try {
      final file = File(_logFilePath!);
      final timestamp = DateTime.now().toIso8601String();
      final authorName = isUser ? "User" : "AI Assistant";
      final userId =
          isUser ? AIAssistantMessages.user.id : AIAssistantMessages.aiUser.id;
      final logEntry = "[$timestamp] [$authorName] [$userId]: $messageText\n";

      await file.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      Logger().e("Error appending message to log file: $e");
    }
  }

  /// Loads conversation history from obsi_ai.md in the vault and restores the chat state.
  /// If the file doesn't exist, no history is loaded.
  Future<AIAssistantMessages?> loadConversationHistory() async {
    try {
      final file = File(_logFilePath);
      if (!await file.exists()) {
        Logger().i("AI log file does not exist: $_logFilePath");
        return null;
      }

      Logger().i("Loading messages from history file: $_logFilePath");

      final content = await file.readAsString();
      final lines =
          content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      final lastMessages = AIAssistantMessages.init();
      // Parse each log entry and recreate messages
      for (final line in lines) {
        final parsedMessage = _parseLogEntry(line);
        if (parsedMessage != null) {
          if (parsedMessage['isUser'] as bool) {
            lastMessages.addRequest(parsedMessage['content'] as String);
          } else {
            lastMessages.addCustomResponse(
                [parsedMessage['content'] as String], "text");
          }
        }
      }

      // Emit the restored state
      return AIAssistantMessages(lastMessages);
    } catch (e) {
      Logger().e("Error loading conversation history: $e");
      return null;
    }
  }

  /// Parses a single log entry line and extracts message information.
  /// Returns null if the line cannot be parsed.
  Map<String, dynamic>? _parseLogEntry(String line) {
    try {
      // Expected format: [timestamp] [Author] [UserID]: message content
      final timestampEnd = line.indexOf('] [');
      if (timestampEnd == -1) return null;

      final authorStart = timestampEnd + 3;
      final authorEnd = line.indexOf('] [', authorStart);
      if (authorEnd == -1) {
        // Fallback to old format: [timestamp] [Author]: message content
        final oldAuthorEnd = line.indexOf(']: ', authorStart);
        if (oldAuthorEnd == -1) return null;

        final author = line.substring(authorStart, oldAuthorEnd);
        final content = line.substring(oldAuthorEnd + 3);

        return {
          'isUser': author == 'User',
          'content': content,
          'userId': author == 'User'
              ? AIAssistantMessages.user.id
              : AIAssistantMessages.aiUser.id,
        };
      }

      final author = line.substring(authorStart, authorEnd);
      final userIdStart = authorEnd + 3;
      final userIdEnd = line.indexOf(']: ', userIdStart);
      if (userIdEnd == -1) return null;

      final userId = line.substring(userIdStart, userIdEnd);
      final content = line.substring(userIdEnd + 3);

      return {
        'isUser': author == 'User',
        'content': content,
        'userId': userId,
      };
    } catch (e) {
      Logger().w("Failed to parse log entry: $line");
      return null;
    }
  }
}
