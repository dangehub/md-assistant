import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsi/src/core/utils.dart';

void main() {
  group('buildHighlightedTextSpans', () {
    test('highlights matching text case-insensitively', () {
      const text = 'Hello World';
      const highlight = 'world';
      final spans = buildHighlightedTextSpans(
          text,
          highlight,
          TextStyle(color: Colors.black),
          TextStyle(backgroundColor: Colors.yellow));

      expect(spans.length, 2);
      expect((spans[0] as TextSpan).text, 'Hello ');
      expect((spans[0] as TextSpan).style?.color, Colors.black);
      expect((spans[1] as TextSpan).text, 'World');
      expect((spans[1] as TextSpan).style?.backgroundColor, Colors.yellow);
    });

    test('highlights matching text case-insensitively', () {
      const text = 'Hello World';
      const highlight = 'h';
      final spans = buildHighlightedTextSpans(
          text,
          highlight,
          TextStyle(color: Colors.black),
          TextStyle(backgroundColor: Colors.yellow));

      expect(spans.length, 2);
      expect((spans[0] as TextSpan).text, 'H');
      expect((spans[0] as TextSpan).style?.backgroundColor, Colors.yellow);
      expect((spans[1] as TextSpan).text, 'ello World');
    });

    test('returns full text when no match is found', () {
      const text = 'Hello World';
      const highlight = 'test';
      final spans = buildHighlightedTextSpans(text, highlight,
          TextStyle(color: Colors.black), TextStyle(color: Colors.yellow));

      expect(spans.length, 1);
      expect((spans[0] as TextSpan).text, 'Hello World');
      expect((spans[0] as TextSpan).style?.color, Colors.black);
    });

    test('handles multiple matches', () {
      const text = 'Hello World, World!';
      const highlight = 'world';
      final spans = buildHighlightedTextSpans(
          text,
          highlight,
          TextStyle(color: Colors.black),
          TextStyle(backgroundColor: Colors.yellow));

      expect(spans.length, 5);
      expect((spans[0] as TextSpan).text, 'Hello ');
      expect((spans[1] as TextSpan).text, 'World');
      expect((spans[1] as TextSpan).style?.backgroundColor, Colors.yellow);
      expect((spans[2] as TextSpan).text, ', ');
      expect((spans[3] as TextSpan).text, 'World');
      expect((spans[3] as TextSpan).style?.backgroundColor, Colors.yellow);
      expect((spans[4] as TextSpan).text, '!');
    });

    test('handles empty highlight', () {
      const text = 'Hello World';
      const highlight = '';
      final spans = buildHighlightedTextSpans(text, highlight,
          TextStyle(color: Colors.black), TextStyle(color: Colors.yellow));

      expect(spans.length, 1);
      expect((spans[0] as TextSpan).text, 'Hello World');
      expect((spans[0] as TextSpan).style?.color, Colors.black);
    });

    test('handles empty text', () {
      const text = '';
      const highlight = 'world';
      final spans = buildHighlightedTextSpans(text, highlight,
          TextStyle(color: Colors.black), TextStyle(color: Colors.yellow));

      expect(spans[0].text!.isEmpty, true);
    });
  });
}
