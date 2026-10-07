enum NotesBlockKind { heading, bullet, paragraph }

final class NotesBlock {
  const NotesBlock(this.kind, this.text);

  const NotesBlock.heading(String text) : this(NotesBlockKind.heading, text);

  const NotesBlock.bullet(String text) : this(NotesBlockKind.bullet, text);

  const NotesBlock.paragraph(String text)
    : this(NotesBlockKind.paragraph, text);

  final NotesBlockKind kind;
  final String text;

  NotesBlock withText(String text) => NotesBlock(kind, text);

  @override
  bool operator ==(Object other) =>
      other is NotesBlock && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'NotesBlock(${kind.name}: $text)';
}

const String plainBullet = '• ';

final RegExp _headingLine = RegExp(r'^#{1,6}\s+(.*)$');
final RegExp _bulletLine = RegExp(r'^\s*[-*•]\s+(.*)$');
final RegExp _indented = RegExp(r'^\s+\S');
final RegExp _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final RegExp _emphasis = RegExp(r'\*\*|__|`');
final RegExp _spaces = RegExp(r'\s+');

String _inline(String text) => text
    .replaceAllMapped(_link, (match) => match[1]!)
    .replaceAll(_emphasis, '')
    .replaceAll(_spaces, ' ')
    .trim();

final RegExp _markdownMark = RegExp(r'^(#{1,6}|\s*[-*])\s');

List<NotesBlock> parseReleaseNotes(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final plain =
      !lines.any(_markdownMark.hasMatch) &&
      lines.any((line) => line.trimLeft().startsWith(plainBullet));
  return plain ? _parsePlain(lines) : _parseMarkdown(lines);
}

List<NotesBlock> _parsePlain(List<String> lines) {
  bool blank(int index) =>
      index < 0 || index >= lines.length || lines[index].trim().isEmpty;
  return List.unmodifiable([
    for (final (index, line) in lines.indexed)
      if (!blank(index))
        if (line.trimLeft().startsWith(plainBullet.trim()))
          NotesBlock.bullet(_inline(line.trimLeft().substring(1)))
        else if (blank(index - 1) && !blank(index + 1))
          NotesBlock.heading(_inline(line))
        else
          NotesBlock.paragraph(_inline(line)),
  ]);
}

List<NotesBlock> _parseMarkdown(List<String> lines) {
  final blocks = <NotesBlock>[];
  final paragraph = <String>[];
  var afterBlank = true;

  void flush() {
    if (paragraph.isNotEmpty) {
      blocks.add(NotesBlock.paragraph(_inline(paragraph.join(' '))));
      paragraph.clear();
    }
  }

  for (final line in lines) {
    if (line.trim().isEmpty) {
      flush();
      afterBlank = true;
      continue;
    }
    if (_headingLine.firstMatch(line) case final match?) {
      flush();
      blocks.add(NotesBlock.heading(_inline(match[1]!)));
    } else if (_bulletLine.firstMatch(line) case final match?) {
      flush();
      blocks.add(NotesBlock.bullet(_inline(match[1]!)));
    } else if (_indented.hasMatch(line) &&
        paragraph.isEmpty &&
        !afterBlank &&
        blocks.isNotEmpty &&
        blocks.last.kind == NotesBlockKind.bullet) {
      final last = blocks.removeLast();
      blocks.add(last.withText(_inline('${last.text} $line')));
    } else {
      paragraph.add(line.trim());
    }
    afterBlank = false;
  }
  flush();
  return List.unmodifiable(blocks);
}

String plainReleaseNotes(String text) {
  final blocks = parseReleaseNotes(text);
  return [
    for (final (index, block) in blocks.indexed)
      switch (block.kind) {
        NotesBlockKind.heading => index == 0 ? block.text : '\n${block.text}',
        NotesBlockKind.bullet => '$plainBullet${block.text}',
        NotesBlockKind.paragraph =>
          index == 0 || blocks[index - 1].kind == NotesBlockKind.heading
              ? block.text
              : '\n${block.text}',
      },
  ].join('\n');
}
