import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'memo_parser.dart';

/// Writes new memos to the appropriate file based on path configuration.
///
/// Supports two modes:
/// 1. **Static path**: Appends to a single file under the appropriate date header
/// 2. **Dynamic path**: Appends to the resolved daily file
class MemoWriter {
  static final _logger = Logger();

  /// Write a new memo with the current timestamp.
  ///
  /// [vaultDir]: The vault root directory
  /// [memosPath]: The path template or static path
  /// [isDynamic]: Whether the path contains variables
  /// [content]: The memo content (without the time prefix)
  /// [dateTime]: Optional custom datetime (defaults to now)
  static Future<bool> writeMemo({
    required String vaultDir,
    required String memosPath,
    required bool isDynamic,
    required String content,
    DateTime? dateTime,
  }) async {
    dateTime ??= DateTime.now();

    final timeStr = _formatTime(dateTime);
    final memoLine = '- $timeStr $content';

    try {
      if (isDynamic) {
        return await _writeToDynamicPath(
            vaultDir, memosPath, memoLine, dateTime);
      } else {
        return await _writeToStaticPath(
            vaultDir, memosPath, memoLine, dateTime);
      }
    } catch (e) {
      _logger.e('Error writing memo: $e');
      return false;
    }
  }

  /// Format the time as HH:mm
  static String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Format the date as YYYY-MM-DD for headers
  static String _formatDateHeader(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  /// Write to a static memos file with date headers.
  static Future<bool> _writeToStaticPath(
    String vaultDir,
    String filePath,
    String memoLine,
    DateTime dateTime,
  ) async {
    final fullPath =
        p.join(vaultDir, filePath.endsWith('.md') ? filePath : '$filePath.md');
    final file = File(fullPath);
    final dateHeader = '# ${_formatDateHeader(dateTime)}';

    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    } else {
      // Create parent directories if needed
      await file.parent.create(recursive: true);
    }

    // Check if today's date header exists
    final headerPattern =
        RegExp('^${RegExp.escape(dateHeader)}\s*\$', multiLine: true);

    if (headerPattern.hasMatch(content)) {
      // Find the position to insert (after the header and existing memos for that date)
      final lines = content.split('\n');
      final newLines = <String>[];
      bool foundHeader = false;
      bool inserted = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        newLines.add(line);

        if (!inserted && line.trim() == dateHeader) {
          foundHeader = true;
          continue;
        }

        if (foundHeader && !inserted) {
          // Check if this is a memo line or the next date header
          if (line.startsWith('# ') ||
              (i + 1 < lines.length && lines[i + 1].startsWith('# '))) {
            // Insert before next header or at end of memos for this date
            if (!line.startsWith('- ')) {
              newLines.insert(newLines.length - 1, memoLine);
              inserted = true;
            }
          } else if (i == lines.length - 1) {
            // End of file, add after last line
            newLines.add(memoLine);
            inserted = true;
          }
        }
      }

      // If we found header but couldn't insert (rare edge case)
      if (foundHeader && !inserted) {
        newLines.add(memoLine);
      }

      await file.writeAsString(newLines.join('\n'));
    } else {
      // Add new date header at the top (newest first)
      final newContent = '$dateHeader\n$memoLine\n\n$content';
      await file.writeAsString(newContent.trimRight() + '\n');
    }

    _logger.i('Memo written to static path: $fullPath');
    return true;
  }

  /// Write to a dynamic path (daily file).
  static Future<bool> _writeToDynamicPath(
    String vaultDir,
    String template,
    String memoLine,
    DateTime dateTime,
  ) async {
    // Resolve the template for today
    final resolvedPath = VariableResolver.resolve(template, date: dateTime);
    final fullPath = p.join(vaultDir,
        resolvedPath.endsWith('.md') ? resolvedPath : '$resolvedPath.md');
    final file = File(fullPath);

    // Create parent directories if needed
    await file.parent.create(recursive: true);

    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    }

    // Append memo to the end
    final newContent =
        content.isEmpty ? '$memoLine\n' : '${content.trimRight()}\n$memoLine\n';

    await file.writeAsString(newContent);

    _logger.i('Memo written to dynamic path: $fullPath');
    return true;
  }

  /// Delete a memo from its source file.
  ///
  /// [sourcePath]: The absolute path to the source file
  /// [lineNumber]: The 1-indexed line number to delete
  static Future<bool> deleteMemo(String sourcePath, int lineNumber) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        _logger.w('Source file not found: $sourcePath');
        return false;
      }

      final lines = (await file.readAsString()).split('\n');
      if (lineNumber < 1 || lineNumber > lines.length) {
        _logger.w('Line number out of range: $lineNumber');
        return false;
      }

      lines.removeAt(lineNumber - 1);
      await file.writeAsString(lines.join('\n'));

      _logger.i('Memo deleted from line $lineNumber in $sourcePath');
      return true;
    } catch (e) {
      _logger.e('Error deleting memo: $e');
      return false;
    }
  }
}
