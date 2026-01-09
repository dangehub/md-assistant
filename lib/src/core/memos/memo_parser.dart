import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import 'memo.dart';

/// Resolves {{variable}} placeholders in path templates.
///
/// Supports moment.js-like date tokens:
/// - YYYY: 4-digit year
/// - YY: 2-digit year
/// - MM: 2-digit month
/// - DD: 2-digit day
/// - HH: 24-hour hour
/// - mm: minute
/// - ss: second
class VariableResolver {
  static final _variablePattern = RegExp(r'\{\{([^}]+)\}\}');

  /// Check if the template contains any variables.
  static bool hasVariables(String template) {
    return _variablePattern.hasMatch(template);
  }

  /// Resolve all {{...}} variables in the template string.
  static String resolve(String template, {DateTime? date}) {
    if (template.isEmpty) return template;
    date ??= DateTime.now();

    return template.replaceAllMapped(_variablePattern, (match) {
      final token = match.group(1)!;
      return _formatDate(token, date!);
    });
  }

  /// Convert a resolved path back to a date (for parsing existing files).
  /// Returns null if the path doesn't match the template pattern.
  static DateTime? extractDate(String path, String template,
      {bool debug = false}) {
    // Build a regex from the template to extract date components
    var pattern = template;
    final captures = <String>[];

    // Process tokens in order of appearance by finding and replacing them left to right
    // First, find all token positions
    final tokenPattern = RegExp(r'\{\{(YYYY-MM-DD|YYYY|MM|DD)\}\}');

    // Replace tokens one by one, tracking capture groups
    pattern = pattern.replaceAllMapped(tokenPattern, (match) {
      final token = match.group(1)!;
      switch (token) {
        case 'YYYY-MM-DD':
          captures.add('year');
          captures.add('month');
          captures.add('day');
          return r'(\d{4})-(\d{2})-(\d{2})';
        case 'YYYY':
          captures.add('year');
          return r'(\d{4})';
        case 'MM':
          captures.add('month');
          return r'(\d{2})';
        case 'DD':
          captures.add('day');
          return r'(\d{2})';
        default:
          return match.group(0)!;
      }
    });

    // Escape special regex characters in the remaining template
    pattern = pattern.replaceAll('.', r'\.');
    pattern = pattern.replaceAll('-', r'\-');

    // Normalize path separators
    pattern = pattern.replaceAll('/', r'[\\/]');

    final regexPattern = '^$pattern\$';
    if (debug) {
      Logger().d('[extractDate] Template: $template');
      Logger().d('[extractDate] Generated regex: $regexPattern');
      Logger().d('[extractDate] Testing path: $path');
      Logger().d('[extractDate] Captures order: $captures');
    }

    final regex = RegExp(regexPattern);
    final match = regex.firstMatch(path);
    if (match == null) {
      if (debug) {
        Logger().d('[extractDate] NO MATCH');
      }
      return null;
    }

    int year = DateTime.now().year;
    int month = 1;
    int day = 1;

    for (int i = 0; i < captures.length; i++) {
      final value = int.tryParse(match.group(i + 1) ?? '') ?? 0;
      switch (captures[i]) {
        case 'year':
          year = value;
          break;
        case 'month':
          month = value;
          break;
        case 'day':
          day = value;
          break;
      }
    }

    if (debug) {
      Logger().d('[extractDate] MATCHED: $year-$month-$day');
    }
    return DateTime(year, month, day);
  }

  static String _formatDate(String format, DateTime date) {
    var result = format;

    // Year
    result = result.replaceAll('YYYY', DateFormat('yyyy').format(date));
    result = result.replaceAll('YY', DateFormat('yy').format(date));

    // Month
    result = result.replaceAll('MMMM', DateFormat('MMMM').format(date));
    result = result.replaceAll('MMM', DateFormat('MMM').format(date));
    result = result.replaceAll('MM', DateFormat('MM').format(date));

    // Day
    result = result.replaceAll('DD', DateFormat('dd').format(date));

    // Day of week
    result = result.replaceAll('dddd', DateFormat('EEEE').format(date));
    result = result.replaceAll('ddd', DateFormat('EEE').format(date));

    // Hour
    result = result.replaceAll('HH', DateFormat('HH').format(date));
    result = result.replaceAll('hh', DateFormat('hh').format(date));

    // Minutes
    result = result.replaceAll('mm', DateFormat('mm').format(date));

    // Seconds
    result = result.replaceAll('ss', DateFormat('ss').format(date));

    return result;
  }
}

/// Parses memos from diary files.
///
/// Supports two path modes:
/// 1. **Static path**: A single file (e.g., `memos.md`) with date headers (`# YYYY-MM-DD`)
/// 2. **Dynamic path**: A template (e.g., `{{YYYY}}/{{YYYY-MM-DD}}.md`) that resolves to multiple files
class MemoParser {
  static final _logger = Logger();

  /// Regex to match memo lines: `- HH:mm(:ss)? content`
  static final _memoPattern =
      RegExp(r'^-\s+(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)$', multiLine: true);

  /// Regex to match date headers: `# YYYY-MM-DD` or similar
  static final _dateHeaderPattern =
      RegExp(r'^#\s*(\d{4}-\d{2}-\d{2})\s*$', multiLine: true);

  /// Parse all memos from the specified path configuration.
  ///
  /// [vaultDir]: The vault root directory
  /// [memosPath]: The path template or static path
  /// [isDynamic]: Whether the path contains variables
  static Future<List<Memo>> parseAll({
    required String vaultDir,
    required String memosPath,
    required bool isDynamic,
  }) async {
    final memos = <Memo>[];

    _logger.d('[MemoParser] parseAll called');
    _logger.d('[MemoParser] vaultDir: $vaultDir');
    _logger.d('[MemoParser] memosPath: $memosPath');
    _logger.d('[MemoParser] isDynamic: $isDynamic');

    if (isDynamic) {
      _logger.d('[MemoParser] Using DYNAMIC path mode');
      memos.addAll(await _parseDynamicPath(vaultDir, memosPath));
    } else {
      _logger.d('[MemoParser] Using STATIC path mode');
      memos.addAll(await _parseStaticPath(vaultDir, memosPath));
    }

    _logger.d('[MemoParser] Total memos found: ${memos.length}');

    // Sort by date descending (newest first)
    memos.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return memos;
  }

  /// Parse memos from a static file with date headers.
  static Future<List<Memo>> _parseStaticPath(
      String vaultDir, String filePath) async {
    final memos = <Memo>[];
    final fullPath =
        p.join(vaultDir, filePath.endsWith('.md') ? filePath : '$filePath.md');
    final file = File(fullPath);

    if (!await file.exists()) {
      _logger.d('Static memos file not found: $fullPath');
      return memos;
    }

    try {
      final content = await file.readAsString();
      final lines = content.split('\n');

      DateTime? currentDate;
      int lineNumber = 0;

      for (final line in lines) {
        lineNumber++;

        // Check for date header
        final headerMatch = _dateHeaderPattern.firstMatch(line);
        if (headerMatch != null) {
          final dateStr = headerMatch.group(1)!;
          currentDate = DateTime.tryParse(dateStr);
          continue;
        }

        // Skip if no current date context
        if (currentDate == null) continue;

        // Check for memo line
        final memoMatch = _memoPattern.firstMatch(line);
        if (memoMatch != null) {
          final timeStr = memoMatch.group(1)!;
          final contentText = memoMatch.group(2)!;

          memos.add(Memo.fromParsed(
            date: currentDate,
            timeString: timeStr,
            content: contentText,
            sourcePath: fullPath,
            lineNumber: lineNumber,
          ));
        }
      }
    } catch (e) {
      _logger.e('Error parsing static memos file: $e');
    }

    return memos;
  }

  static Future<List<Memo>> _parseDynamicPath(
      String vaultDir, String template) async {
    final memos = <Memo>[];

    _logger.d('[MemoParser] _parseDynamicPath template: $template');

    // Find all matching files by scanning the vault
    final matchingFiles = await _findMatchingFiles(vaultDir, template);
    _logger.d('[MemoParser] Found ${matchingFiles.length} matching files');

    for (final entry in matchingFiles.entries) {
      final file = entry.key;
      final date = entry.value;

      try {
        final content = await file.readAsString();
        final lines = content.split('\n');
        int lineNumber = 0;

        for (final line in lines) {
          lineNumber++;
          final memoMatch = _memoPattern.firstMatch(line);
          if (memoMatch != null) {
            final timeStr = memoMatch.group(1)!;
            final contentText = memoMatch.group(2)!;

            memos.add(Memo.fromParsed(
              date: date,
              timeString: timeStr,
              content: contentText,
              sourcePath: file.path,
              lineNumber: lineNumber,
            ));
          }
        }
      } catch (e) {
        _logger.e('Error parsing dynamic memo file ${file.path}: $e');
      }
    }

    return memos;
  }

  /// Find all files that match the dynamic path template.
  static Future<Map<File, DateTime>> _findMatchingFiles(
      String vaultDir, String template) async {
    final results = <File, DateTime>{};

    _logger.d('[MemoParser] _findMatchingFiles scanning: $vaultDir');
    _logger.d('[MemoParser] Template for matching: $template');

    // Remove .md extension for pattern matching
    final templateWithoutExt = template.endsWith('.md')
        ? template.substring(0, template.length - 3)
        : template;
    _logger.d('[MemoParser] Template without ext: $templateWithoutExt');

    final directory = Directory(vaultDir);

    if (!await directory.exists()) {
      _logger.w('[MemoParser] Vault directory does not exist: $vaultDir');
      return results;
    }

    int scannedFiles = 0;
    int diaryFilesLogged = 0;
    // Scan files recursively
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        // Get relative path from vault
        final relativePath =
            p.relative(entity.path, from: vaultDir).replaceAll('\\', '/');

        // Skip hidden directories (like .stversions, .obsidian, etc.)
        if (relativePath.startsWith('.') || relativePath.contains('/.')) {
          continue;
        }

        scannedFiles++;
        final relativePathWithoutExt = relativePath.endsWith('.md')
            ? relativePath.substring(0, relativePath.length - 3)
            : relativePath;

        // Log first few diary files that START with the expected path
        if (relativePath.startsWith('101-日记/') && diaryFilesLogged < 3) {
          diaryFilesLogged++;
          _logger.d(
              '[DEBUG] Diary file #$diaryFilesLogged: $relativePathWithoutExt');
          _logger.d('[DEBUG] Template: $templateWithoutExt');
          // Test extraction with debug
          VariableResolver.extractDate(
              relativePathWithoutExt, templateWithoutExt,
              debug: true);
        }

        // Try to extract date from this path using the template
        final date = VariableResolver.extractDate(
            relativePathWithoutExt, templateWithoutExt);
        if (date != null) {
          // Verify the resolved template matches this path
          final resolvedTemplate =
              VariableResolver.resolve(templateWithoutExt, date: date);
          if (relativePathWithoutExt == resolvedTemplate ||
              relativePathWithoutExt ==
                  resolvedTemplate.replaceAll('/', '\\')) {
            _logger.d('[MemoParser] MATCHED: $relativePath -> $date');
            results[entity] = date;
          }
        }
      }
    }
    _logger.d(
        '[MemoParser] Scanned $scannedFiles .md files, matched ${results.length}');

    return results;
  }

  /// Parse memos from a single file content with a known date.
  static List<Memo> parseFromContent(String content, DateTime date,
      {String? sourcePath}) {
    final memos = <Memo>[];
    final lines = content.split('\n');
    int lineNumber = 0;

    for (final line in lines) {
      lineNumber++;
      final memoMatch = _memoPattern.firstMatch(line);
      if (memoMatch != null) {
        final timeStr = memoMatch.group(1)!;
        final contentText = memoMatch.group(2)!;

        memos.add(Memo.fromParsed(
          date: date,
          timeString: timeStr,
          content: contentText,
          sourcePath: sourcePath,
          lineNumber: lineNumber,
        ));
      }
    }

    return memos;
  }
}
