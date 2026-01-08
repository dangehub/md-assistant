import 'package:path/path.dart' as p;

/// 从文件名中提取日期的工具类
class FilenameDateExtractor {
  // 支持的日期格式模式
  static final List<RegExp> _datePatterns = [
    // YYYY-MM-DD 格式（最常用）
    RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
    // YYYY.MM.DD 格式
    RegExp(r'(\d{4})\.(\d{2})\.(\d{2})'),
    // YYYY/MM/DD 格式
    RegExp(r'(\d{4})/(\d{2})/(\d{2})'),
    // YYYYMMDD 格式
    RegExp(r'(\d{4})(\d{2})(\d{2})'),
  ];

  /// 从文件路径中提取日期
  /// 如果文件名或路径包含有效日期，返回该日期
  /// 否则返回 null
  static DateTime? extractDateFromPath(String filePath) {
    if (filePath.isEmpty) return null;

    // 获取文件名（不含扩展名）
    final fileName = p.basenameWithoutExtension(filePath);

    // 也检查完整路径，因为日期可能在文件夹名中
    // 例如: /vault/2026/01/08/note.md
    final pathToCheck = filePath;

    // 先尝试从文件名中提取
    DateTime? date = _extractDateFromString(fileName);
    if (date != null) return date;

    // 如果文件名没有日期，尝试从路径中提取
    date = _extractDateFromString(pathToCheck);
    return date;
  }

  /// 从字符串中提取日期
  static DateTime? _extractDateFromString(String input) {
    for (final pattern in _datePatterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        try {
          final year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);

          // 验证日期有效性
          if (_isValidDate(year, month, day)) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          // 解析失败，继续尝试下一个模式
          continue;
        }
      }
    }
    return null;
  }

  /// 验证日期是否有效
  static bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    // 更精确的天数验证
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) return false;

    return true;
  }

  /// 检查文件名是否看起来像日记文件
  /// 日记文件通常以日期命名，例如 2026-01-08.md
  static bool looksLikeDailyNote(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    // 如果文件名主要由日期组成，则认为是日记
    final datePattern = RegExp(r'^\d{4}[-./]?\d{2}[-./]?\d{2}$');
    return datePattern.hasMatch(fileName);
  }
}
