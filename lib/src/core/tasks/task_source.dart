import 'dart:convert';

import 'package:crypto/crypto.dart';

enum TaskType { taskNote, markdown }

class TaskSource {
  final String fileName;
  final int fileNumber;
  final int offset;
  final int length;
  final int id;
  final TaskType type;

  TaskSource(this.fileNumber, this.fileName, this.offset, this.length,
      {this.type = TaskType.markdown})
      : id = _calculateId(fileName, offset);

  static int _calculateId(String fileName, int offset) {
    var path = fileName + offset.toString();
    var bytes = utf8.encode(path);
    var digest = sha256.convert(bytes);
    // Convert the first 4 bytes of the hash to a 32-bit integer
    return digest.bytes.sublist(0, 4).fold(0, (a, b) => (a << 8) | b) &
        0x7FFFFFFF;
  }

  @override
  String toString() {
    return "#$fileNumber File: $fileName\nOffset: $offset\nLength: $length";
  }
}
