import 'package:flutter/material.dart';

import '../../ui/app_type.dart';
import '../../ui/board_theme.dart';

/// Renders the small slice of Markdown a language model actually emits.
///
/// Answers came back with their syntax showing -- `###` in front of
/// headings, `**` around emphasis, a literal hyphen starting every
/// bullet. The model writes Markdown because that is what models do;
/// rendering it is our side of the bargain.
///
/// Not a Markdown library. Chat answers use headings, emphasis,
/// bullets, numbered steps and inline code, and a general parser brings
/// tables, footnotes and reference links that will never appear, along
/// with its own typography to fight. This handles that subset and
/// leaves anything it does not recognise as plain text, which is the
/// right failure: a stray character reads as a typo, where a crash or a
/// blank answer does not.
class AnswerText extends StatelessWidget {
  final String text;
  final Color color;

  /// Emphasis and headings.
  final Color strongColor;

  const AnswerText({
    super.key,
    required this.text,
    required this.color,
    required this.strongColor,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = parse(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i].spacingAbove),
          _block(context, blocks[i]),
        ],
      ],
    );
  }

  Widget _block(BuildContext context, AnswerBlock block) {
    final style = switch (block.kind) {
      AnswerBlockKind.heading => AppType.heading(
        fontSize: block.level <= 1 ? 18 : 16,
        color: strongColor,
      ),
      _ => AppType.body(color: color),
    };

    final body = SelectableText.rich(
      TextSpan(children: _inline(block.text, style)),
      style: style,
    );

    if (block.marker == null) return body;

    // Markers sit in their own column so wrapped lines stay aligned
    // under the text rather than under the bullet.
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              block.marker!,
              style: AppType.body(color: color).copyWith(height: style.height),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// Splits a line into runs of plain, bold, italic and code.
  List<TextSpan> _inline(String source, TextStyle base) {
    final spans = <TextSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    var i = 0;
    while (i < source.length) {
      final rest = source.substring(i);

      // Bold first: `**` also matches the italic rule, so testing the
      // shorter marker first would split every bold run into two
      // italics around an empty middle.
      final bold = _delimited(rest, '**');
      if (bold != null) {
        flush();
        spans.add(
          TextSpan(
            text: bold.content,
            style: base.copyWith(
              fontWeight: FontWeight.w600,
              color: strongColor,
            ),
          ),
        );
        i += bold.length;
        continue;
      }

      final italic = _delimited(rest, '*') ?? _delimited(rest, '_');
      if (italic != null) {
        flush();
        spans.add(
          TextSpan(
            text: italic.content,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        i += italic.length;
        continue;
      }

      final code = _delimited(rest, '`');
      if (code != null) {
        flush();
        spans.add(
          TextSpan(
            text: code.content,
            style: base.copyWith(
              fontFeatures: null,
              letterSpacing: 0.2,
              background: Paint()
                ..color = BoardColors.ink.withValues(alpha: 0.06),
            ),
          ),
        );
        i += code.length;
        continue;
      }

      buffer.write(source[i]);
      i++;
    }

    flush();
    return spans;
  }

  /// A run wrapped in [mark], or null if this is not the start of one.
  ///
  /// Rejects an empty body so `**` on its own, and the `* ` of a bullet
  /// that survived block parsing, stay as text rather than swallowing
  /// the rest of the line.
  static ({String content, int length})? _delimited(
    String source,
    String mark,
  ) {
    if (!source.startsWith(mark)) return null;
    final end = source.indexOf(mark, mark.length);
    if (end <= mark.length) return null;
    return (
      content: source.substring(mark.length, end),
      length: end + mark.length,
    );
  }

  /// Breaks an answer into blocks. Public for testing: the parsing is
  /// where the mistakes are, and it can be checked without a tree.
  static List<AnswerBlock> parse(String source) {
    final blocks = <AnswerBlock>[];

    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;

      final heading = RegExp(r'^\s*(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        blocks.add(
          AnswerBlock(
            kind: AnswerBlockKind.heading,
            text: heading.group(2)!.trim(),
            level: heading.group(1)!.length,
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        blocks.add(
          AnswerBlock(
            kind: AnswerBlockKind.bullet,
            text: bullet.group(1)!.trim(),
            marker: '•',
          ),
        );
        continue;
      }

      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        blocks.add(
          AnswerBlock(
            kind: AnswerBlockKind.numbered,
            text: numbered.group(2)!.trim(),
            marker: '${numbered.group(1)}.',
          ),
        );
        continue;
      }

      blocks.add(
        AnswerBlock(kind: AnswerBlockKind.paragraph, text: line.trim()),
      );
    }

    return blocks;
  }
}

enum AnswerBlockKind { paragraph, heading, bullet, numbered }

class AnswerBlock {
  final AnswerBlockKind kind;
  final String text;
  final int level;
  final String? marker;

  const AnswerBlock({
    required this.kind,
    required this.text,
    this.level = 0,
    this.marker,
  });

  /// A heading needs air above it; list items sit close together.
  double get spacingAbove => switch (kind) {
    AnswerBlockKind.heading => 16,
    AnswerBlockKind.paragraph => 12,
    _ => 6,
  };
}
