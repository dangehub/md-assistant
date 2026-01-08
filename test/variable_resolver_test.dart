import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/variable_resolver.dart';

void main() {
  group('VariableResolver', () {
    // 使用固定日期进行测试
    final testDate = DateTime(2026, 1, 8, 14, 30, 45);

    group('基础日期格式化', () {
      test('YYYY 返回4位年份', () {
        expect(
          VariableResolver.resolve('{{YYYY}}', date: testDate),
          equals('2026'),
        );
      });

      test('YY 返回2位年份', () {
        expect(
          VariableResolver.resolve('{{YY}}', date: testDate),
          equals('26'),
        );
      });

      test('MM 返回2位月份', () {
        expect(
          VariableResolver.resolve('{{MM}}', date: testDate),
          equals('01'),
        );
      });

      test('M 返回1-2位月份', () {
        expect(
          VariableResolver.resolve('{{M}}', date: testDate),
          equals('1'),
        );
      });

      test('DD 返回2位日期', () {
        expect(
          VariableResolver.resolve('{{DD}}', date: testDate),
          equals('08'),
        );
      });

      test('D 返回1-2位日期', () {
        expect(
          VariableResolver.resolve('{{D}}', date: testDate),
          equals('8'),
        );
      });

      test('HH 返回24小时制小时', () {
        expect(
          VariableResolver.resolve('{{HH}}', date: testDate),
          equals('14'),
        );
      });

      test('mm 返回分钟', () {
        expect(
          VariableResolver.resolve('{{mm}}', date: testDate),
          equals('30'),
        );
      });

      test('ss 返回秒', () {
        expect(
          VariableResolver.resolve('{{ss}}', date: testDate),
          equals('45'),
        );
      });
    });

    group('组合格式', () {
      test('YYYY-MM-DD 返回完整日期', () {
        expect(
          VariableResolver.resolve('{{YYYY-MM-DD}}', date: testDate),
          equals('2026-01-08'),
        );
      });

      test('YYYY/MM/DD 返回斜杠分隔日期', () {
        expect(
          VariableResolver.resolve('{{YYYY/MM/DD}}', date: testDate),
          equals('2026/01/08'),
        );
      });

      test('HH:mm:ss 返回完整时间', () {
        expect(
          VariableResolver.resolve('{{HH:mm:ss}}', date: testDate),
          equals('14:30:45'),
        );
      });
    });

    group('路径模板', () {
      test('日记路径模板', () {
        expect(
          VariableResolver.resolve('daily/{{YYYY}}/{{YYYY-MM-DD}}.md',
              date: testDate),
          equals('daily/2026/2026-01-08.md'),
        );
      });

      test('按月归档路径', () {
        expect(
          VariableResolver.resolve('{{YYYY}}/{{MM}}/tasks.md', date: testDate),
          equals('2026/01/tasks.md'),
        );
      });

      test('混合静态和动态内容', () {
        expect(
          VariableResolver.resolve('notes/{{YYYY-MM-DD}}_daily.md',
              date: testDate),
          equals('notes/2026-01-08_daily.md'),
        );
      });
    });

    group('边界情况', () {
      test('无变量字符串原样返回', () {
        expect(
          VariableResolver.resolve('simple/path/file.md', date: testDate),
          equals('simple/path/file.md'),
        );
      });

      test('空字符串返回空', () {
        expect(
          VariableResolver.resolve('', date: testDate),
          equals(''),
        );
      });

      test('未闭合的花括号不解析', () {
        expect(
          VariableResolver.resolve('{{YYYY', date: testDate),
          equals('{{YYYY'),
        );
      });

      test('嵌套花括号只解析内部变量', () {
        // {{{YYYY}}} -> { + 2026 + }
        final result = VariableResolver.resolve('{{{YYYY}}}', date: testDate);
        expect(result, equals('{2026}'));
      });
    });

    group('hasVariables', () {
      test('检测包含变量', () {
        expect(VariableResolver.hasVariables('{{YYYY}}/file.md'), isTrue);
      });

      test('检测不包含变量', () {
        expect(VariableResolver.hasVariables('simple/file.md'), isFalse);
      });
    });

    group('默认日期', () {
      test('不传日期参数使用当前时间', () {
        final result = VariableResolver.resolve('{{YYYY}}');
        expect(result, equals(DateTime.now().year.toString()));
      });
    });
  });
}
