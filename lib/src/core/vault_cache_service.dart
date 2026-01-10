import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for scanning and caching vault data (tags and wiki links).
/// This enables autocomplete functionality in the Memos input.
class VaultCacheService {
  static VaultCacheService? _instance;

  // Cached data
  final Set<String> _tags = {};
  final Set<String> _wikiLinks = {};
  final List<String> _recentTags = [];
  final List<String> _recentWikiLinks = [];

  // Patterns
  static final RegExp _tagPattern = RegExp(r'#([\w\u4e00-\u9fff]+)');
  static final RegExp _wikiLinkPattern =
      RegExp(r'\[\[([^\]|]+)(?:\|[^\]]+)?\]\]');

  // Preferences keys
  static const String _recentTagsKey = 'vault_cache_recent_tags';
  static const String _recentWikiLinksKey = 'vault_cache_recent_wiki_links';
  static const String _lastScanKey = 'vault_cache_last_scan';

  VaultCacheService._();

  static VaultCacheService get instance {
    _instance ??= VaultCacheService._();
    return _instance!;
  }

  /// Get all cached tags
  Set<String> get tags => _tags;

  /// Get all cached wiki links
  Set<String> get wikiLinks => _wikiLinks;

  /// Get recent tags (up to [limit])
  List<String> getRecentTags({int limit = 3}) {
    return _recentTags.take(limit).toList();
  }

  /// Get recent wiki links (up to [limit])
  List<String> getRecentWikiLinks({int limit = 3}) {
    return _recentWikiLinks.take(limit).toList();
  }

  /// Search tags matching the query with relevance sorting
  List<String> searchTags(String query, {int limit = 5}) {
    if (query.isEmpty) {
      return getRecentTags(limit: limit);
    }
    final lowerQuery = query.toLowerCase();

    // Score each tag by relevance
    final scored = <MapEntry<String, int>>[];
    for (final tag in _tags) {
      final lowerTag = tag.toLowerCase();
      int score = 0;

      if (lowerTag == lowerQuery) {
        score = 100; // Exact match
      } else if (lowerTag.startsWith(lowerQuery)) {
        score = 80; // Starts with query
      } else if (lowerTag.contains(lowerQuery)) {
        final index = lowerTag.indexOf(lowerQuery);
        score = 60 - (index > 40 ? 40 : index);
      }

      if (score > 0) {
        scored.add(MapEntry(tag, score));
      }
    }

    // Sort by score descending, then by length
    scored.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return a.key.length.compareTo(b.key.length);
    });

    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Search wiki links matching the query with relevance sorting
  List<String> searchWikiLinks(String query, {int limit = 5}) {
    if (query.isEmpty) {
      return getRecentWikiLinks(limit: limit);
    }
    final lowerQuery = query.toLowerCase();

    // Score each link by relevance
    final scored = <MapEntry<String, int>>[];
    for (final link in _wikiLinks) {
      final lowerLink = link.toLowerCase();
      int score = 0;

      if (lowerLink == lowerQuery) {
        score = 100; // Exact match
      } else if (lowerLink.startsWith(lowerQuery)) {
        score = 80; // Starts with query
      } else if (lowerLink.contains(lowerQuery)) {
        // Higher score for matches earlier in the string
        final index = lowerLink.indexOf(lowerQuery);
        score = 60 - (index > 40 ? 40 : index);
      }

      if (score > 0) {
        scored.add(MapEntry(link, score));
      }
    }

    // Sort by score descending, then by length (shorter = more relevant)
    scored.sort((a, b) {
      final scoreCompare = b.value.compareTo(a.value);
      if (scoreCompare != 0) return scoreCompare;
      return a.key.length.compareTo(b.key.length);
    });

    return scored.take(limit).map((e) => e.key).toList();
  }

  /// Record usage of a tag (moves it to the front of recent list)
  Future<void> recordTagUsage(String tag) async {
    _recentTags.remove(tag);
    _recentTags.insert(0, tag);
    if (_recentTags.length > 20) {
      _recentTags.removeLast();
    }
    await _saveRecentData();
  }

  /// Record usage of a wiki link (moves it to the front of recent list)
  Future<void> recordWikiLinkUsage(String link) async {
    _recentWikiLinks.remove(link);
    _recentWikiLinks.insert(0, link);
    if (_recentWikiLinks.length > 20) {
      _recentWikiLinks.removeLast();
    }
    await _saveRecentData();
  }

  /// Scan the vault directory and cache all tags and wiki links
  Future<void> scanVault(String vaultDir) async {
    if (vaultDir.isEmpty) return;

    final directory = Directory(vaultDir);
    if (!await directory.exists()) return;

    _tags.clear();
    _wikiLinks.clear();

    await _scanDirectory(directory);

    // Also add all .md file names as potential wiki links
    await _scanFileNames(directory);

    // Load recent usage data
    await _loadRecentData();

    // Save last scan time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Recursively scan a directory for .md files
  Future<void> _scanDirectory(Directory dir) async {
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        // Skip hidden directories
        if (entity.path.contains('/.') || entity.path.contains('\\.')) {
          continue;
        }

        if (entity is File && entity.path.endsWith('.md')) {
          await _parseFile(entity);
        }
      }
    } catch (e) {
      // Ignore permission errors
    }
  }

  /// Parse a single file for tags and wiki links
  Future<void> _parseFile(File file) async {
    try {
      final content = await file.readAsString();

      // Extract tags
      for (final match in _tagPattern.allMatches(content)) {
        final tag = match.group(1);
        if (tag != null && tag.isNotEmpty) {
          _tags.add(tag);
        }
      }

      // Extract wiki links
      for (final match in _wikiLinkPattern.allMatches(content)) {
        final link = match.group(1);
        if (link != null && link.isNotEmpty) {
          _wikiLinks.add(link.trim());
        }
      }
    } catch (e) {
      // Ignore read errors
    }
  }

  /// Scan all .md file names as potential wiki link targets
  Future<void> _scanFileNames(Directory dir) async {
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        // Skip hidden directories
        if (entity.path.contains('/.') || entity.path.contains('\\.')) {
          continue;
        }

        if (entity is File && entity.path.endsWith('.md')) {
          // Extract filename without extension
          final fileName = entity.uri.pathSegments.last;
          final linkName = fileName.replaceAll('.md', '');
          if (linkName.isNotEmpty) {
            _wikiLinks.add(linkName);
          }
        }
      }
    } catch (e) {
      // Ignore permission errors
    }
  }

  /// Load recent usage data from SharedPreferences
  Future<void> _loadRecentData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTags = prefs.getStringList(_recentTagsKey);
    if (savedTags != null) {
      _recentTags.clear();
      _recentTags.addAll(savedTags);
    }

    final savedLinks = prefs.getStringList(_recentWikiLinksKey);
    if (savedLinks != null) {
      _recentWikiLinks.clear();
      _recentWikiLinks.addAll(savedLinks);
    }
  }

  /// Save recent usage data to SharedPreferences
  Future<void> _saveRecentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentTagsKey, _recentTags);
    await prefs.setStringList(_recentWikiLinksKey, _recentWikiLinks);
  }

  /// Check if vault needs to be rescanned (e.g., after 1 hour)
  Future<bool> needsRescan() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScan = prefs.getInt(_lastScanKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Rescan if more than 1 hour has passed
    return (now - lastScan) > 3600000;
  }
}
