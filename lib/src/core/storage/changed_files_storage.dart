import 'package:logger/logger.dart';

import 'storage_interfaces.dart';
import 'dart:io';

class ChangedFilesStorage implements TasksFileStorage {
  final TasksFileStorage wrapped;
  String _path;
  final Map<String, DateTime> _lastModifiedTimes = {};

  ChangedFilesStorage(this.wrapped) : _path = "";

  @override
  Future<List<TasksFile>> getAllFiles(String path) async {
    if (_path != path) {
      _lastModifiedTimes.clear();
    }

    _path = path;
    final allFiles = await wrapped.getAllFiles(_path);
    final changedFiles = <TasksFile>[];

    //Logger().d("All files: ${allFiles.join('\n')}");

    for (final file in allFiles) {
      final lastModified = await File(file.path).lastModified();
      if (!_lastModifiedTimes.containsKey(file.path) ||
          _lastModifiedTimes[file.path]!.isBefore(lastModified)) {
        _lastModifiedTimes[file.path] = lastModified;
        changedFiles.add(file);
      }
    }

    Logger().d("Changed files: ${changedFiles.join('\n')}");

    return changedFiles;
  }

  @override
  TasksFile getFile(String path) {
    return wrapped.getFile(path);
  }

  @override
  String? todayFile;
}
