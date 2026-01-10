import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path_utils;

enum PublishStatus { uploaded, skipped, failed }

class PublishService {
  final _logger = Logger();

  /// Publishes a file to a remote Git repository via API.
  /// Currently supports GitHub REST API.
  Future<PublishStatus> publishFile({
    required File file,
    required String repoUrl, // e.g., https://github.com/owner/repo.git
    required String repoToken,
    required String targetPath, // e.g., src/site/notes/
    String branch = 'main',
    bool skipIfExists = false,
  }) async {
    if (!file.existsSync()) {
      _logger.e('File not found: ${file.path}');
      return PublishStatus.failed;
    }

    // 1. Parse Repo URL
    final repoInfo = _parseGitHubUrl(repoUrl);
    if (repoInfo == null) {
      _logger.e('Invalid or unsupported repository URL: $repoUrl');
      throw Exception(
          'Invalid GitHub URL. Must be in format https://github.com/owner/repo[.git]');
    }

    final owner = repoInfo['owner'];
    final repo = repoInfo['repo'];
    final filename = path_utils.basename(file.path);

    // Construct target path (ensure no double slashes and ends with filename)
    var finalPath = targetPath;
    if (finalPath.endsWith('/')) {
      finalPath += filename;
    } else if (path_utils.extension(finalPath).isEmpty) {
      // If it looks like a directory (no extension), append filename
      finalPath += '/$filename';
    }
    // Remove leading slash if present
    if (finalPath.startsWith('/')) finalPath = finalPath.substring(1);

    final apiUrl = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/contents/$finalPath');

    try {
      final content = base64Encode(await file.readAsBytes());

      // 2. Check if file exists (to get SHA)
      String? sha;
      final getResponse = await http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $repoToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (getResponse.statusCode == 200) {
        if (skipIfExists) {
          _logger.d('File exists and skipIfExists is true. Skipping upload.');
          return PublishStatus.skipped;
        }
        final json = jsonDecode(getResponse.body);
        sha = json['sha'];
        _logger.d('File exists, updating. SHA: $sha');
      } else if (getResponse.statusCode == 404) {
        _logger.d('File does not exist, creating new.');
      } else {
        _logger.e(
            'Error checking file: ${getResponse.statusCode} ${getResponse.body}');
        return PublishStatus.failed;
      }

      // 3. Create or Update file
      final body = jsonEncode({
        'message': 'Update microblog via MD Bro',
        'content': content,
        'branch': branch,
        if (sha != null) 'sha': sha,
      });

      final putResponse = await http.put(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $repoToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
        _logger.i('Successfully published to $finalPath');
        return PublishStatus.uploaded;
      } else {
        _logger.e(
            'Failed to publish: ${putResponse.statusCode} ${putResponse.body}');
        throw Exception('GitHub API Error: ${putResponse.statusCode}');
      }
    } catch (e) {
      _logger.e('Publish error: $e');
      rethrow;
    }
  }

  /// Returns the number of files successfully uploaded (not skipped)
  /// [onProgress] is called with (current index, total count, status message)
  /// This optimized version fetches the remote file list in 1 API call,
  /// then only uploads files that don't exist.
  Future<int> publishAssets({
    required List<File> files,
    required List<String> remotePaths,
    required String repoUrl,
    required String repoToken,
    String branch = 'main',
    void Function(int current, int total, String message)? onProgress,
  }) async {
    if (files.length != remotePaths.length) {
      throw Exception('Files and remotePaths must have same length');
    }

    if (files.isEmpty) return 0;

    // 1. Parse repo info
    final repoInfo = _parseGitHubUrl(repoUrl);
    if (repoInfo == null) {
      throw Exception('Invalid GitHub URL');
    }
    final owner = repoInfo['owner']!;
    final repo = repoInfo['repo']!;

    // 2. Extract common directory from first remotePath
    // Assuming all assets go to the same directory
    final firstPath = remotePaths.first;
    final dirPath = firstPath.contains('/')
        ? firstPath.substring(0, firstPath.lastIndexOf('/'))
        : '';

    // 3. Fetch existing files in the remote directory (1 API call)
    onProgress?.call(0, files.length, '正在获取远程文件列表...');
    final existingFiles = await _fetchRemoteFileList(
      owner: owner,
      repo: repo,
      path: dirPath,
      token: repoToken,
    );
    _logger.d('Found ${existingFiles.length} existing files in $dirPath');

    // 4. Filter out files that already exist
    final filesToUpload = <int>[];
    for (var i = 0; i < files.length; i++) {
      final filename = path_utils.basename(remotePaths[i]);
      if (!existingFiles.contains(filename)) {
        filesToUpload.add(i);
      }
    }

    _logger.d(
        '${filesToUpload.length} files need to be uploaded out of ${files.length}');

    // 5. Upload only missing files
    int uploadedCount = 0;
    for (var j = 0; j < filesToUpload.length; j++) {
      final i = filesToUpload[j];
      final filename = path_utils.basename(files[i].path);
      onProgress?.call(j + 1, filesToUpload.length, '上传 $filename');

      try {
        final status = await publishFile(
          file: files[i],
          repoUrl: repoUrl,
          repoToken: repoToken,
          targetPath: remotePaths[i],
          branch: branch,
          skipIfExists: false, // We already know it doesn't exist
        );
        if (status == PublishStatus.uploaded) {
          uploadedCount++;
        }
      } catch (e) {
        _logger.e('Failed to publish asset ${files[i].path}: $e');
        onProgress?.call(j + 1, filesToUpload.length, '失败: $filename');
      }
    }

    // Final status
    if (filesToUpload.isEmpty) {
      onProgress?.call(files.length, files.length, '所有附件已存在，无需上传');
    }

    return uploadedCount;
  }

  /// Fetches the list of filenames in a remote directory.
  /// Returns an empty set if the directory doesn't exist.
  Future<Set<String>> _fetchRemoteFileList({
    required String owner,
    required String repo,
    required String path,
    required String token,
  }) async {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final apiUrl = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/contents/$cleanPath');

    try {
      final response = await http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        return items
            .where((item) => item['type'] == 'file')
            .map<String>((item) => item['name'] as String)
            .toSet();
      } else if (response.statusCode == 404) {
        // Directory doesn't exist yet
        _logger.d('Remote directory does not exist: $cleanPath');
        return {};
      } else {
        _logger.e('Error fetching directory: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      _logger.e('Error fetching remote file list: $e');
      return {};
    }
  }

  Map<String, String>? _parseGitHubUrl(String url) {
    // Basic parser for https://github.com/owner/repo.git or https://github.com/owner/repo
    // Supports dots in repo name (e.g. username.github.io)
    final regex = RegExp(r'github\.com[:/]([\w-]+)/([\w\.-]+?)(\.git)?$');
    final match = regex.firstMatch(url);
    if (match != null) {
      return {
        'owner': match.group(1)!,
        'repo': match.group(2)!,
      };
    }
    return null;
  }
}
