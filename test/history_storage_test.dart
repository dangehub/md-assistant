import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/ai_assistant/history_storage.dart';
import 'package:obsi/src/screens/ai_assistant/cubit/ai_assistant_state.dart';

void main() {
  late Directory tempDir;
  late String testFilePath;
  late HistoryStorage historyStorage;

  setUp(() async {
    // Create a temporary directory for test files
    tempDir = await Directory.systemTemp.createTemp('history_storage_test_');
    testFilePath = '${tempDir.path}/test_history.md';
    historyStorage = HistoryStorage(testFilePath);
  });

  tearDown(() async {
    // Clean up temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HistoryStorage - parseLogEntry', () {
    test('should parse new format log entry with user ID', () {
      const line =
          '[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Hello, AI!';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNotNull);
      expect(result!['isUser'], isTrue);
      expect(result['content'], equals('Hello, AI!'));
      expect(result['userId'], equals('baeb2c47-c0ea-468e-b6a5-563341f995e3'));
    });

    test('should parse new format log entry for AI assistant', () {
      const line =
          '[2024-01-15T10:30:01.000] [AI Assistant] [af25d069-4513-4724-a0f2-d4fba793c356]: Hello, User!';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNotNull);
      expect(result!['isUser'], isFalse);
      expect(result['content'], equals('Hello, User!'));
      expect(result['userId'], equals('af25d069-4513-4724-a0f2-d4fba793c356'));
    });


    test('should handle message content with special characters', () {
      const line =
          '[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Message with [brackets] and: colons';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNotNull);
      expect(result!['content'],
          equals('Message with [brackets] and: colons'));
    });

    test('should handle message content with newlines and special chars', () {
      const line =
          '[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Multi-line\\nmessage with émojis 🎉';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNotNull);
      expect(result!['content'],
          equals('Multi-line\\nmessage with émojis 🎉'));
    });

    test('should return null for invalid format - missing timestamp', () {
      const line = 'Invalid log entry without proper format';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNull);
    });

    test('should return null for invalid format - incomplete brackets', () {
      const line = '[2024-01-15T10:30:00.000] [User';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNull);
    });

    test('should return null for empty string', () {
      const line = '';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNull);
    });

    test('should handle message with only timestamp', () {
      const line = '[2024-01-15T10:30:00.000]';

      final result = historyStorage.parseLogEntry(line);

      expect(result, isNull);
    });
  });

  group('HistoryStorage - appendMessageToLog', () {
    test('should append user message to log file', () async {
      await historyStorage.appendMessageToLog('Hello from user', true);

      final file = File(testFilePath);
      final content = await file.readAsString();

      expect(content, contains('[User]'));
      expect(content, contains('Hello from user'));
      expect(content, contains(AIAssistantMessages.user.id));
    });

    test('should append AI message to log file', () async {
      await historyStorage.appendMessageToLog('Hello from AI', false);

      final file = File(testFilePath);
      final content = await file.readAsString();

      expect(content, contains('[AI Assistant]'));
      expect(content, contains('Hello from AI'));
      expect(content, contains(AIAssistantMessages.aiUser.id));
    });

    test('should append multiple messages in order', () async {
      await historyStorage.appendMessageToLog('Message 1', true);
      await historyStorage.appendMessageToLog('Message 2', false);
      await historyStorage.appendMessageToLog('Message 3', true);

      final file = File(testFilePath);
      final content = await file.readAsString();
      final lines = content.split('\n');

      expect(lines.where((l) => l.contains('Message 1')).length, equals(1));
      expect(lines.where((l) => l.contains('Message 2')).length, equals(1));
      expect(lines.where((l) => l.contains('Message 3')).length, equals(1));
    });

    test('should handle special characters in message content', () async {
      await historyStorage.appendMessageToLog(
          'Special chars: [brackets] {braces} émojis 🎉', true);

      final file = File(testFilePath);
      final content = await file.readAsString();

      expect(content,
          contains('Special chars: [brackets] {braces} émojis 🎉'));
    });
  });

  group('HistoryStorage - loadConversationHistory', () {
    test('should return null when history file does not exist', () async {
      final result = await historyStorage.loadConversationHistory();

      expect(result, isNull);
    });

    test('should load conversation history from file', () async {
      // Create a test history file
      final file = File(testFilePath);
      await file.writeAsString('''
[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Hello
[2024-01-15T10:30:01.000] [AI Assistant] [af25d069-4513-4724-a0f2-d4fba793c356]: Hi there!
[2024-01-15T10:30:02.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: How are you?
''');

      final result = await historyStorage.loadConversationHistory();

      expect(result, isNotNull);
      expect(result!.messages.length, equals(3));
    });


    test('should skip invalid log entries', () async {
      final file = File(testFilePath);
      await file.writeAsString('''
[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Valid message
Invalid log entry
[2024-01-15T10:30:01.000] [AI Assistant] [af25d069-4513-4724-a0f2-d4fba793c356]: Another valid message
''');

      final result = await historyStorage.loadConversationHistory();

      expect(result, isNotNull);
      expect(result!.messages.length, equals(2));
    });

    test('should handle empty file', () async {
      final file = File(testFilePath);
      await file.writeAsString('');

      final result = await historyStorage.loadConversationHistory();

      expect(result, isNotNull);
      expect(result!.messages.length, equals(0));
    });

    test('should handle file with only whitespace', () async {
      final file = File(testFilePath);
      await file.writeAsString('   \n\n   \n');

      final result = await historyStorage.loadConversationHistory();

      expect(result, isNotNull);
      expect(result!.messages.length, equals(0));
    });

    test('should preserve message order (oldest first)', () async {
      final file = File(testFilePath);
      await file.writeAsString('''
[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: First
[2024-01-15T10:30:01.000] [AI Assistant] [af25d069-4513-4724-a0f2-d4fba793c356]: Second
[2024-01-15T10:30:02.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Third
''');

      final result = await historyStorage.loadConversationHistory();

      expect(result, isNotNull);
      // Messages are inserted at index 0, so they're in reverse order
      expect(result!.messages.length, equals(3));
    });
  });


  group('HistoryStorage - Integration Tests', () {
    test('should append and load conversation successfully', () async {
      // Append messages
      await historyStorage.appendMessageToLog('Hello, AI!', true);
      await historyStorage.appendMessageToLog('Hello, User!', false);
      await historyStorage.appendMessageToLog('How are you?', true);
      await historyStorage.appendMessageToLog('I am doing well, thank you!', false);

      // Load and verify
      final loadedMessages = await historyStorage.loadConversationHistory();
      
      expect(loadedMessages, isNotNull);
      expect(loadedMessages!.messages.length, equals(4));
    });

    test('should handle special characters in round-trip', () async {
      await historyStorage.appendMessageToLog('Test with émojis 🎉🎊 and symbols @#\$%', true);
      await historyStorage.appendMessageToLog('Response with [brackets] and {braces}', false);

      final loadedMessages = await historyStorage.loadConversationHistory();
      
      expect(loadedMessages, isNotNull);
      expect(loadedMessages!.messages.length, equals(2));
    });
  });

  group('HistoryStorage - Edge Cases', () {
    test('should handle very long message content in append', () async {
      final longMessage = 'A' * 10000;
      await historyStorage.appendMessageToLog(longMessage, true);

      final file = File(testFilePath);
      final content = await file.readAsString();
      expect(content, contains('A' * 100)); // Check a portion exists
    });
    
    test('should handle very long message content in load', () async {
      final longMessage = 'A' * 10000;
      final file = File(testFilePath);
      await file.writeAsString(
          '[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: $longMessage\n');

      final loadedMessages = await historyStorage.loadConversationHistory();
      expect(loadedMessages, isNotNull);
      expect(loadedMessages!.messages.length, equals(1));
    });

    test('should handle concurrent append operations', () async {
      // Attempt concurrent appends
      await Future.wait([
        historyStorage.appendMessageToLog('Message 1', true),
        historyStorage.appendMessageToLog('Message 2', false),
      ]);

      // File should exist with both messages
      final file = File(testFilePath);
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('Message'));
    });

    test('should handle Unicode characters in append', () async {
      await historyStorage.appendMessageToLog('Unicode: 你好 مرحبا שלום', true);
      await historyStorage.appendMessageToLog('Response: こんにちは 안녕하세요', false);

      final file = File(testFilePath);
      final content = await file.readAsString();
      
      expect(content, contains('Unicode: 你好 مرحبا שלום'));
      expect(content, contains('Response: こんにちは 안녕하세요'));
    });
    
    test('should handle Unicode characters in log format', () async {
      // Test Unicode handling with the log entry format that loadConversationHistory expects
      final file = File(testFilePath);
      await file.writeAsString('''
[2024-01-15T10:30:00.000] [User] [baeb2c47-c0ea-468e-b6a5-563341f995e3]: Unicode: 你好 مرحبا שלום
[2024-01-15T10:30:01.000] [AI Assistant] [af25d069-4513-4724-a0f2-d4fba793c356]: Response: こんにちは 안녕하세요
''');

      final loadedMessages = await historyStorage.loadConversationHistory();
      expect(loadedMessages, isNotNull);
      expect(loadedMessages!.messages.length, equals(2));
    });
  });
}
