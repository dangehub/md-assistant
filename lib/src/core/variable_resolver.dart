import 'package:intl/intl.dart';

/// 通用变量解析器，支持 {{}} 双花括号语法
/// 使用 moment.js 风格的日期格式化 token
class VariableResolver {
  /// 解析字符串中的所有 {{}} 变量
  /// [template] 包含变量的模板字符串
  /// [date] 用于日期变量的时间，默认为当前时间
  static String resolve(String template, {DateTime? date}) {
    if (template.isEmpty) return template;

    date ??= DateTime.now();

    // 匹配 {{...}} 模式，捕获花括号内的内容
    final regex = RegExp(r'\{\{([^}]+)\}\}');

    return template.replaceAllMapped(regex, (match) {
      final token = match.group(1)!;
      return _formatDate(token, date!);
    });
  }

  /// 检查字符串是否包含变量
  static bool hasVariables(String template) {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(template);
  }

  /// 将 moment.js 风格的 token 转换为日期字符串
  static String _formatDate(String format, DateTime date) {
    // 直接构建结果字符串，逐个处理 moment.js token
    String result = format;

    // 使用有序的替换，从最长的 token 开始，避免子字符串冲突
    // 年份
    result = result.replaceAll('YYYY', DateFormat('yyyy').format(date));
    result = result.replaceAll('YY', DateFormat('yy').format(date));

    // 月份 - 注意顺序：先长后短
    result = result.replaceAll('MMMM', DateFormat('MMMM').format(date));
    result = result.replaceAll('MMM', DateFormat('MMM').format(date));
    result = result.replaceAll('MM', DateFormat('MM').format(date));
    // M 需要特殊处理，避免影响已替换的内容
    result = _replaceToken(result, 'M', date.month.toString());

    // 日期 - 使用大写 D 表示日期（与 moment.js 一致）
    result = result.replaceAll('DDDD', DateFormat('DDD').format(date)); // 年中第几天
    result = result.replaceAll('DD', DateFormat('dd').format(date));
    result = _replaceToken(result, 'D', date.day.toString());

    // 星期 - 使用小写 d（与 moment.js 一致）
    result = result.replaceAll('dddd', DateFormat('EEEE').format(date));
    result = result.replaceAll('ddd', DateFormat('EEE').format(date));

    // 小时
    result = result.replaceAll('HH', DateFormat('HH').format(date));
    result = _replaceToken(result, 'H', date.hour.toString());
    result = result.replaceAll('hh', DateFormat('hh').format(date));
    result = _replaceToken(result, 'h', DateFormat('h').format(date));

    // 分钟
    result = result.replaceAll('mm', DateFormat('mm').format(date));
    result = _replaceToken(result, 'm', date.minute.toString());

    // 秒
    result = result.replaceAll('ss', DateFormat('ss').format(date));
    result = _replaceToken(result, 's', date.second.toString());

    // AM/PM
    result = result.replaceAll('A', DateFormat('a').format(date).toUpperCase());
    result = _replaceToken(result, 'a', DateFormat('a').format(date));

    // 周数
    result = result.replaceAll('ww', DateFormat('ww').format(date));
    result = _replaceToken(result, 'w', DateFormat('w').format(date));

    // 季度
    result = _replaceToken(result, 'Q', ((date.month - 1) ~/ 3 + 1).toString());

    return result;
  }

  /// 安全替换单字符 token，避免影响已替换的内容
  /// 只替换独立的 token（前后不是字母的情况）
  static String _replaceToken(String input, String token, String replacement) {
    // 对于单字符 token，我们需要确保不会替换已经是数字一部分的字符
    // 这里使用简单策略：只有当 token 是独立存在时才替换
    final regex = RegExp('(?<![a-zA-Z])$token(?![a-zA-Z])');
    return input.replaceAll(regex, replacement);
  }

  /// 获取支持的 token 列表（用于帮助文档）
  static List<String> getSupportedTokens() {
    return [
      'YYYY',
      'YY',
      'MMMM',
      'MMM',
      'MM',
      'M',
      'DDDD',
      'DD',
      'D',
      'dddd',
      'ddd',
      'HH',
      'H',
      'hh',
      'h',
      'mm',
      'm',
      'ss',
      's',
      'A',
      'a',
      'ww',
      'w',
      'Q'
    ];
  }
}
