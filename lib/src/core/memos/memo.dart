/// Represents a single memo entry parsed from a note file.
///
/// Memos follow the format: `- HH:mm(:ss)? content`
/// and are typically written in daily notes or a dedicated memos file.
class Memo {
  /// The full date and time of the memo
  final DateTime dateTime;

  /// The raw content of the memo (may contain Markdown/HTML)
  final String content;

  /// The source file path where this memo was found
  final String? sourcePath;

  /// The line number in the source file (1-indexed)
  final int? lineNumber;

  /// The date portion only (for grouping)
  DateTime get date => DateTime(dateTime.year, dateTime.month, dateTime.day);

  /// The time string (HH:mm or HH:mm:ss)
  String get timeString {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    if (dateTime.second > 0) {
      final second = dateTime.second.toString().padLeft(2, '0');
      return '$hour:$minute:$second';
    }
    return '$hour:$minute';
  }

  const Memo({
    required this.dateTime,
    required this.content,
    this.sourcePath,
    this.lineNumber,
  });

  /// Create a Memo from parsed components
  factory Memo.fromParsed({
    required DateTime date,
    required String timeString,
    required String content,
    String? sourcePath,
    int? lineNumber,
  }) {
    final timeParts = timeString.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;
    final second = int.tryParse(timeParts.length > 2 ? timeParts[2] : '0') ?? 0;

    return Memo(
      dateTime: DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
        second,
      ),
      content: content,
      sourcePath: sourcePath,
      lineNumber: lineNumber,
    );
  }

  @override
  String toString() => 'Memo($timeString: $content)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Memo &&
          runtimeType == other.runtimeType &&
          dateTime == other.dateTime &&
          content == other.content &&
          sourcePath == other.sourcePath;

  @override
  int get hashCode =>
      dateTime.hashCode ^ content.hashCode ^ (sourcePath?.hashCode ?? 0);
}
