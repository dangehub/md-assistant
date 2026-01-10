import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// A custom Markdown renderer that supports additional syntax:
/// - ==highlight== for yellow background
/// - <font color="#rrggbb">text</font> for colored text
/// - <u>text</u> for underline
class MemoRenderer extends StatelessWidget {
  final String content;
  final String? vaultDirectory;
  final TextStyle? baseStyle;

  const MemoRenderer({
    super.key,
    required this.content,
    this.vaultDirectory,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Pre-process content to convert custom syntax to standard markdown/HTML
    final processedContent = _preprocessContent(content);

    return MarkdownBody(
      data: processedContent,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle ?? Theme.of(context).textTheme.bodyMedium,
        a: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      onTapLink: (text, href, title) => _handleLinkTap(href),
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          HighlightSyntax(),
          FontColorSyntax(),
          UnderlineSyntax(),
        ],
      ),
      builders: {
        'mark': MarkBuilder(),
        'font': FontBuilder(),
        'u': UnderlineBuilder(),
      },
      imageBuilder: (uri, title, alt) => _buildImage(uri, title, alt),
    );
  }

  /// Pre-process content to handle special cases
  String _preprocessContent(String content) {
    var result = content;

    // Convert ![[filename]] into ![filename](filename)
    // Supports optional pipe for resizing ![[filename|100]] -> ![filename|100](filename)
    // Note: We ignore the size for now in the image builder logic, but preserving it in alt text is fine.
    // We MUST encode the filename because Markdown specs don't support spaces in URLs without encoding.
    result = result.replaceAllMapped(
      RegExp(r'!\[\[([^\]|]+)(?:\|([^\]]+))?\]\]'),
      (match) {
        final fileName = match.group(1)!;
        final altText = match.group(2) ?? fileName;
        // Encode spaces and special chars to allow markdown parsing
        final encodedPath = Uri.encodeFull(fileName);
        return '![$altText]($encodedPath)';
      },
    );

    // Convert ==text== to <mark>text</mark>
    result = result.replaceAllMapped(
      RegExp(r'==([^=]+)=='),
      (match) => '<mark>${match.group(1)}</mark>',
    );

    return result;
  }

  void _handleLinkTap(String? href) async {
    if (href == null || href.isEmpty) return;

    final uri = Uri.tryParse(href);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildImage(Uri uri, String? title, String? alt) {
    // Decode the path to get the actual filename on disk (e.g. %20 -> space)
    final src = Uri.decodeFull(uri.toString());

    // Check if remote
    if (src.startsWith('http')) {
      return Image.network(src);
    }

    // Local file handling
    if (vaultDirectory == null) {
      return const SizedBox(); // Cannot resolve without vault dir
    }

    final File strictFile = File('$vaultDirectory/$src');
    if (strictFile.existsSync()) {
      return Image.file(strictFile);
    }

    // If direct lookup fails, try finding the file recursively (Shortest Path support)
    return FutureBuilder<File?>(
      future: _findFileRecursive(Directory(vaultDirectory!), src),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data != null) {
            return Image.file(snapshot.data!);
          } else {
            return _buildImageError(src);
          }
        }
        // Show a small placeholder while searching
        return Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(4),
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }

  Widget _buildImageError(String src) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
              child: Text('Not found: $src',
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }

  /// Recursively search for a file with [filename] in [dir].
  /// Returns the first match found.
  Future<File?> _findFileRecursive(Directory dir, String filename) async {
    // Use runZoned or just async to avoid blocking main thread too much,
    // though filesystem ops are somewhat blocking.
    // For a deeper search, we might want to run this in an isolate,
    // but for now simple async recursion is a good start.

    try {
      if (!await dir.exists()) return null;

      final List<FileSystemEntity> entities = await dir.list().toList();

      // 1. Check files in current dir first
      for (final entity in entities) {
        if (entity is File) {
          // simple check: ends with separator + filename, or is just filename
          // We use simple string match on the last segment
          if (entity.path.endsWith(Platform.pathSeparator + filename) ||
              entity.path.endsWith('/$filename') ||
              entity.uri.pathSegments.last == filename) {
            return entity;
          }
        }
      }

      // 2. Recurse into subdirectories
      for (final entity in entities) {
        if (entity is Directory) {
          // Skip hidden directories (like .obsidian, .git)
          final dirname = entity.uri.pathSegments.length > 1
              ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
              : entity.path.split(Platform.pathSeparator).last;

          if (dirname.startsWith('.')) continue;

          final found = await _findFileRecursive(entity, filename);
          if (found != null) return found;
        }
      }
    } catch (e) {
      // Ignore permission errors etc.
    }
    return null;
  }
}

/// Syntax for ==highlight== -> <mark>
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==([^=]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1)!;
    final element = md.Element.text('mark', text);
    parser.addNode(element);
    return true;
  }
}

/// Syntax for <font color="...">text</font>
class FontColorSyntax extends md.InlineSyntax {
  // Match: <font color="value">text</font> or <font color='value'>text</font>
  FontColorSyntax()
      : super(r'<font\s+color=["\x27]([^"\x27]+)["\x27]>([^<]+)</font>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final color = match.group(1)!;
    final text = match.group(2)!;
    final element = md.Element.text('font', text);
    element.attributes['color'] = color;
    parser.addNode(element);
    return true;
  }
}

/// Syntax for <u>text</u>
class UnderlineSyntax extends md.InlineSyntax {
  UnderlineSyntax() : super(r'<u>([^<]+)</u>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match.group(1)!;
    final element = md.Element.text('u', text);
    parser.addNode(element);
    return true;
  }
}

/// Builder for <mark> (highlight) elements
class MarkBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        element.textContent,
        style: preferredStyle,
      ),
    );
  }
}

/// Builder for <font color="..."> elements
class FontBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final colorStr = element.attributes['color'];
    Color? color;

    if (colorStr != null) {
      // Parse color from hex string like #rrggbb or #rgb
      if (colorStr.startsWith('#')) {
        final hex = colorStr.substring(1);
        if (hex.length == 6) {
          color = Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 3) {
          final r = hex[0];
          final g = hex[1];
          final b = hex[2];
          color = Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
        }
      }
    }

    return Text(
      element.textContent,
      style: (preferredStyle ?? const TextStyle()).copyWith(
        color: color,
      ),
    );
  }
}

/// Builder for <u> (underline) elements
class UnderlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Text(
      element.textContent,
      style: (preferredStyle ?? const TextStyle()).copyWith(
        decoration: TextDecoration.underline,
      ),
    );
  }
}
