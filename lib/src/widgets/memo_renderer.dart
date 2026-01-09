import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

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
    );
  }

  /// Pre-process content to handle special cases
  String _preprocessContent(String content) {
    var result = content;

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
