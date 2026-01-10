import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:obsi/src/core/memos/memo.dart';
import 'package:obsi/src/core/memos/memo_parser.dart';
import 'package:obsi/src/screens/settings/settings_controller.dart';
import 'package:obsi/src/screens/settings/settings_service.dart';
import 'package:path/path.dart' as path;

class AggregateResult {
  final File file;
  final List<AssetToPush> assets;

  AggregateResult(this.file, this.assets);
}

class AssetToPush {
  final File localFile;
  final String remotePath; // Relative path in repo

  AssetToPush(this.localFile, this.remotePath);
}

class MemoAggregator {
  final SettingsService _settingsService = SettingsService();

  /// Aggregates memos matching the configured tag and generates the microblog file.
  /// Returns the generated file object and list of assets to push.
  Future<AggregateResult> aggregate() async {
    final settings = SettingsController.getInstance();
    final vaultDir = settings.vaultDirectory;
    final memosPath = settings.memosPath;

    if (vaultDir == null || memosPath == null) {
      throw Exception('Vault directory or Memos path not configured');
    }

    // Load configuration
    final targetTag = await _settingsService.microblogTag();
    final blogTitle = await _settingsService.microblogTitle();
    final avatarPath = await _settingsService.microblogAvatarPath();
    final filename = await _settingsService.microblogFilename();
    final permalink = await _settingsService.microblogPermalink();
    final repoImagePath = await _settingsService.microblogRepoImagePath();
    final webImagePrefix = await _settingsService.microblogWebImagePrefix();
    final username = await _settingsService.microblogUsername();

    // Parse all memos
    final allMemos = await MemoParser.parseAll(
      vaultDir: vaultDir,
      memosPath: memosPath,
      isDynamic: settings.memosPathIsDynamic,
    );

    // Filter by tag
    final validMemos =
        allMemos.where((m) => m.content.contains(targetTag)).toList();

    // Sort by date descending
    validMemos.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final assetsToPush = <AssetToPush>[];

    // Handle Avatar
    String avatarHtml;
    if (avatarPath.startsWith('http')) {
      avatarHtml = '<img src="$avatarPath" alt="Avatar">';
    } else {
      // Local avatar
      final avatarFile = File(path.join(vaultDir, avatarPath));
      if (await avatarFile.exists()) {
        final avatarName = path.basename(avatarPath);
        final remotePath =
            path.join(repoImagePath, avatarName).replaceAll(r'\\', '/');
        final webPath = '$webImagePrefix/$avatarName'
            .replaceAll('//', '/'); // Ensure single slash

        assetsToPush.add(AssetToPush(avatarFile, remotePath));
        avatarHtml = '<img src="$webPath" alt="Avatar">';
      } else {
        // Fallback
        avatarHtml =
            '<img src="https://ui-avatars.com/api/?name=User&background=0D8ABC&color=fff" alt="Avatar">';
      }
    }

    // Determine create/update time from memos
    final createdDate =
        validMemos.isEmpty ? DateTime.now() : validMemos.last.dateTime;
    final updatedDate =
        validMemos.isEmpty ? DateTime.now() : validMemos.first.dateTime;

    // Generate HTML content
    final htmlContent = _generateHtml(
      validMemos,
      blogTitle,
      avatarHtml,
      targetTag,
      vaultDir,
      repoImagePath,
      webImagePrefix,
      assetsToPush,
      username,
    );

    // Generate File Content (Frontmatter + Style + HTML)
    final fileContent = _generateMarkdown(
        blogTitle, htmlContent, permalink, createdDate, updatedDate);

    // Write to file
    final targetFile = File(path.join(vaultDir, filename));
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsString(fileContent);

    return AggregateResult(targetFile, assetsToPush);
  }

  String _generateMarkdown(String title, String html, String permalink,
      DateTime created, DateTime updated) {
    final createdStr = DateFormat('yyyy-MM-ddTHH:mm').format(created);
    final updatedStr = DateFormat('yyyy-MM-ddTHH:mm').format(updated);

    // Construct metadata strictly as requested by user
    // Matching the format: {"dg-publish":true,"title":"...","dg-permalink":"...","permalink":"/.../","dgPassFrontmatter":true,"noteIcon":""}
    final metadata = {
      "dg-publish": true,
      "title": title,
      "dg-permalink": permalink,
      "permalink": "/$permalink/",
      "dgPassFrontmatter": true,
      "updated": updatedStr,
      "created": createdStr,
      "noteIcon": ""
    };

    final jsonMetadata = jsonEncode(metadata);

    // Minified CSS - Large Image Mode (no lightbox, images display full width)
    // Grid changed to single column for better viewing on all devices
    const css =
        """<style>:root{--bg-color:#f5f7fa;--card-bg:#ffffff;--text-primary:#333333;--text-secondary:#666666;--accent-color:#007bff;--border-radius:12px;--box-shadow:0 2px 8px rgba(0,0,0,0.05)}@media(prefers-color-scheme:dark){:root{--bg-color:transparent;--card-bg:#2d2d2d;--text-primary:#e0e0e0;--text-secondary:#aaaaaa;--box-shadow:0 2px 8px rgba(0,0,0,0.2)}}.markdown-preview-view{padding:0!important}.timeline{max-width:600px;width:100%;margin:0 auto;display:flex;flex-direction:column;gap:20px;padding-top:20px}.header{text-align:center;margin-bottom:20px}.header h1{margin:0;font-size:1.5rem;border-bottom:none!important}.header p{color:var(--text-secondary);font-size:0.9rem}.memo-card{background-color:var(--card-bg);border-radius:var(--border-radius);padding:16px;box-shadow:var(--box-shadow);display:flex;gap:12px;transition:transform .2s;border:1px solid rgba(128,128,128,0.1)}.memo-card:hover{transform:translateY(-2px)}.avatar{width:40px;height:40px;border-radius:50%;background-color:#ddd;flex-shrink:0;overflow:hidden}.avatar img{width:100%;height:100%;object-fit:cover;margin:0!important;display:block}.content-area{flex:1}.meta{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}.author{font-weight:600;font-size:.95rem}.time{color:var(--text-secondary);font-size:.8rem}.text{line-height:1.6;margin-bottom:12px;white-space:pre-wrap}.text a{color:var(--accent-color);text-decoration:none}.text .tag{color:var(--accent-color);background-color:rgba(0,123,255,0.1);padding:2px 6px;border-radius:4px;font-size:.85rem}.images-grid{display:flex;flex-direction:column;gap:12px;margin-top:12px}.image-item{border-radius:8px;overflow:hidden;background-color:#eee}.image-item img{width:100%;height:auto;object-fit:contain;margin:0!important;display:block;max-height:500px}</style>""";

    return """---
$jsonMetadata
---
$css
<!-- No newlines between HTML tags to prevent broken layout in some renderers -->
$html
""";
  }

  String _generateHtml(
    List<Memo> memos,
    String title,
    String avatarHtml,
    String targetTag,
    String vaultDir,
    String repoImagePath,
    String webImagePrefix,
    List<AssetToPush> assetsToPush,
    String username,
  ) {
    final sb = StringBuffer();
    sb.write(
        '<div class="timeline"><div class="header"><p>Generated by <a href="https://github.com/dangehub/vaultmate">MD Bro</a></p></div>');

    for (final memo in memos) {
      final processed = _processContent(
        memo.content,
        targetTag,
        vaultDir,
        repoImagePath,
        webImagePrefix,
        assetsToPush,
      );
      final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(memo.dateTime);

      sb.write('<div class="memo-card">');
      sb.write('<div class="avatar">$avatarHtml</div>');
      sb.write('<div class="content-area">');
      sb.write(
          '<div class="meta"><span class="author">$username</span><span class="time">$timeStr</span></div>');
      sb.write('<div class="text">${processed.text}</div>');
      if (processed.images.isNotEmpty) {
        sb.write('<div class="images-grid">');
        for (final img in processed.images) {
          // Flatten images (both thumbnail and lightbox)
          sb.write(img);
        }
        sb.write('</div>');
      }
      sb.write('</div></div>'); // content-area, memo-card
    }

    sb.write('</div>');
    // No script tag needed
    return sb.toString();
  }

  _ProcessedContent _processContent(
    String content,
    String targetTag,
    String vaultDir,
    String repoImagePath,
    String webImagePrefix,
    List<AssetToPush> assetsToPush,
  ) {
    final images = <String>[];
    var cleanText = content;

    // 1. Remove the filter tag (e.g. #mb) with case-insensitive regex
    // Also remove potential trailing space
    if (targetTag.isNotEmpty) {
      final escapedTag = RegExp.escape(targetTag);
      // Match tag, optionally followed by one space
      cleanText = cleanText.replaceAll(
          RegExp('$escapedTag ?', caseSensitive: false), '');
    }

    // Helper to add image (simple, no lightbox - DG strips it anyway)
    void addImage(String webPath, String alt) {
      final html =
          '<div class="image-item"><img src="$webPath" alt="$alt" loading="lazy"></div>';
      images.add(html);
    }

    // 2. Process wiki links ![[filename]]
    final wikiImageRegex = RegExp(r'!\[\[(.*?)\]\]');
    cleanText = cleanText.replaceAllMapped(wikiImageRegex, (match) {
      final filename = match.group(1) ?? ""; // Could be "folder/img.png|size"

      // Handle size or pipe syntax if present
      final pipeIndex = filename.indexOf('|');
      final pathOnly =
          pipeIndex == -1 ? filename : filename.substring(0, pipeIndex);

      final assetPath = path.join(vaultDir, pathOnly);
      final assetFile = File(assetPath);

      if (assetFile.existsSync()) {
        final assetName = path.basename(pathOnly);
        final remotePath =
            path.join(repoImagePath, assetName).replaceAll(r'\\', '/');
        final webPath = '$webImagePrefix/$assetName'.replaceAll('//', '/');

        assetsToPush.add(AssetToPush(assetFile, remotePath));
        addImage(webPath, assetName);
      }
      return ""; // Remove from text
    });

    // 3. Process standard MD images ![alt](url)
    final imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');
    cleanText = cleanText.replaceAllMapped(imageRegex, (match) {
      final alt = match.group(1) ?? "";
      final url = match.group(2) ?? "";

      if (!url.startsWith('http')) {
        // Local file
        final assetPath = path.join(vaultDir, url);
        final assetFile = File(assetPath);

        if (assetFile.existsSync()) {
          final assetName = path.basename(url);
          final remotePath =
              path.join(repoImagePath, assetName).replaceAll(r'\\', '/');

          final assetToPush = AssetToPush(assetFile, remotePath);
          assetsToPush.add(assetToPush);
          final webPath = '$webImagePrefix/$assetName'.replaceAll('//', '/');
          addImage(webPath, alt);
        }
      } else {
        // External
        images.add(
            '<div class="image-item"><img src="$url" alt="$alt" loading="lazy"></div>');
      }
      return "";
    });

    // Clean up
    cleanText = cleanText.trim();

    // Process other tags
    cleanText = cleanText
        .replaceAllMapped(RegExp(r'(?<=^|\s)#([\w\u4e00-\u9fff]+)'), (match) {
      return ' <span class="tag">#${match.group(1)}</span>';
    });

    // Convert newlines to <br> for HTML rendering
    cleanText = cleanText.replaceAll('\n', '<br>');

    return _ProcessedContent(cleanText, images);
  }
}

class _ProcessedContent {
  final String text;
  final List<String> images;

  _ProcessedContent(this.text, this.images);
}
