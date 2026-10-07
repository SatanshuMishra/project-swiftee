enum NotesBlockKind { heading, item, paragraph }

const String bulletMarker = '•';

final class NotesBlock {
  const NotesBlock(this.kind, this.text, {this.marker = '', this.depth = 0});

  const NotesBlock.heading(String text) : this(NotesBlockKind.heading, text);

  const NotesBlock.item(
    String text, {
    String marker = bulletMarker,
    int depth = 0,
  }) : this(NotesBlockKind.item, text, marker: marker, depth: depth);

  const NotesBlock.paragraph(String text)
    : this(NotesBlockKind.paragraph, text);

  final NotesBlockKind kind;
  final String text;
  final String marker;
  final int depth;

  NotesBlock withText(String text) =>
      NotesBlock(kind, text, marker: marker, depth: depth);

  @override
  bool operator ==(Object other) =>
      other is NotesBlock &&
      other.kind == kind &&
      other.text == text &&
      other.marker == marker &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(kind, text, marker, depth);

  @override
  String toString() => switch (kind) {
    NotesBlockKind.item => 'NotesBlock(item $depth $marker: $text)',
    _ => 'NotesBlock(${kind.name}: $text)',
  };
}

List<NotesBlock> parseReleaseNotes(String text) {
  final lines = _lines(text);
  return lines.any(_markdownOnly.hasMatch)
      ? _parseMarkdown(lines)
      : _parsePlain(lines);
}

List<NotesBlock> parseMarkdownNotes(String text) =>
    _parseMarkdown(_lines(text));

String plainReleaseNotes(String markdown) {
  final blocks = parseMarkdownNotes(markdown);
  return [
    for (final (index, block) in blocks.indexed) ...[
      if (index > 0 && _setApart(blocks[index - 1], block)) '',
      switch (block.kind) {
        NotesBlockKind.item =>
          '${_plainIndent * block.depth}${block.marker} ${block.text}',
        _ => block.text,
      },
    ],
  ].join('\n');
}

const String _plainIndent = '  ';

final RegExp _markdownOnly = RegExp(r'^ {0,3}#{1,6}\s|^\s*[-*+]\s');
final RegExp _markdownHeading = RegExp(r'^ {0,3}#{1,6}\s+(.*?)(?:\s+#+)?\s*$');
final RegExp _markdownItem = RegExp(r'^( *)([-*+•]|\d{1,9}[.)])\s+(.*)$');
final RegExp _underline = RegExp(r'^ {0,3}(=+|-+)\s*$');
final RegExp _rule = RegExp(r'^ {0,3}([-*_])(?:\s*\1){2,}\s*$');
final RegExp _plainItem = RegExp(r'^( *)(•|\d{1,9}[.)])\s+(.*)$');
final RegExp _number = RegExp(r'^(\d+)([.)])$');

List<String> _lines(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\t', '    ')
    .split('\n');

bool _setApart(NotesBlock before, NotesBlock block) =>
    before.kind != NotesBlockKind.heading &&
    !(before.kind == NotesBlockKind.item && block.kind == NotesBlockKind.item);

List<NotesBlock> _parsePlain(List<String> lines) {
  bool blank(int index) => index >= lines.length || lines[index].trim().isEmpty;
  return List.unmodifiable([
    for (final (index, line) in lines.indexed)
      if (!blank(index))
        if (_plainItem.firstMatch(line) case final match?)
          NotesBlock.item(
            _collapse(match[3]!),
            marker: match[2]!,
            depth: match[1]!.length ~/ _plainIndent.length,
          )
        else if (!blank(index + 1))
          NotesBlock.heading(_collapse(line))
        else
          NotesBlock.paragraph(_collapse(line)),
  ]);
}

typedef _Markdown = ({
  List<NotesBlock> blocks,
  List<String> paragraph,
  List<int> openItems,
  bool afterBlank,
});

const _Markdown _start = (
  blocks: [],
  paragraph: [],
  openItems: [],
  afterBlank: true,
);

List<NotesBlock> _parseMarkdown(List<String> lines) {
  final blocks = _flush(lines.fold(_start, _readMarkdownLine)).blocks
      .map((block) => block.withText(_inline(block.text)))
      .where((block) => block.text.isNotEmpty)
      .toList();
  final end = blocks.lastIndexWhere(
    (block) => block.kind != NotesBlockKind.heading,
  );
  return List.unmodifiable(blocks.take(end + 1));
}

_Markdown _readMarkdownLine(_Markdown state, String line) {
  if (line.trim().isEmpty) return _broken(_flush(state));
  if (state.paragraph.isNotEmpty && _underline.hasMatch(line)) {
    return (
      blocks: [...state.blocks, NotesBlock.heading(state.paragraph.join(' '))],
      paragraph: const [],
      openItems: const [],
      afterBlank: false,
    );
  }
  if (_rule.hasMatch(line)) return _broken(_flush(state));
  if (_markdownHeading.firstMatch(line) case final match?) {
    return (
      blocks: [..._flush(state).blocks, NotesBlock.heading(match[1]!)],
      paragraph: const [],
      openItems: const [],
      afterBlank: false,
    );
  }
  if (_markdownItem.firstMatch(line) case final match?) {
    final flushed = _flush(state);
    final indent = match[1]!.length;
    final parents = flushed.openItems
        .takeWhile((open) => open + 2 <= indent)
        .toList();
    final depth = parents.length;
    return (
      blocks: [
        ...flushed.blocks,
        NotesBlock.item(
          match[3]!,
          marker: _itemMarker(flushed.blocks, depth, match[2]!),
          depth: depth,
        ),
      ],
      paragraph: const [],
      openItems: [...parents, indent],
      afterBlank: false,
    );
  }
  final last = state.blocks.lastOrNull;
  if (!state.afterBlank &&
      state.paragraph.isEmpty &&
      last?.kind == NotesBlockKind.item) {
    return (
      blocks: [
        ...state.blocks.take(state.blocks.length - 1),
        last!.withText('${last.text} ${line.trim()}'),
      ],
      paragraph: const [],
      openItems: state.openItems,
      afterBlank: false,
    );
  }
  return (
    blocks: state.blocks,
    paragraph: [...state.paragraph, line.trim()],
    openItems: state.openItems,
    afterBlank: false,
  );
}

_Markdown _flush(_Markdown state) => state.paragraph.isEmpty
    ? state
    : (
        blocks: [
          ...state.blocks,
          NotesBlock.paragraph(state.paragraph.join(' ')),
        ],
        paragraph: const [],
        openItems: const [],
        afterBlank: state.afterBlank,
      );

_Markdown _broken(_Markdown state) => (
  blocks: state.blocks,
  paragraph: state.paragraph,
  openItems: state.openItems,
  afterBlank: true,
);

String _itemMarker(List<NotesBlock> blocks, int depth, String written) {
  final number = _number.firstMatch(written);
  if (number == null) return bulletMarker;
  final previous = blocks.reversed
      .takeWhile((block) => block.kind == NotesBlockKind.item)
      .where((block) => block.depth <= depth)
      .firstOrNull;
  final previousNumber = previous?.depth == depth
      ? _number.firstMatch(previous!.marker)
      : null;
  return previousNumber != null && previousNumber[2] == number[2]
      ? '${int.parse(previousNumber[1]!) + 1}${number[2]}'
      : '${int.parse(number[1]!)}${number[2]}';
}

final RegExp _codeSpan = RegExp(r'(`+)(.+?)\1');
final RegExp _escape = RegExp(r'\\([!-/:-@\[-`{-~])');
final RegExp _autolink = RegExp(r'<((?:https?|mailto):[^>\s]+)>');
final RegExp _image = RegExp(r'!\[([^\]]*)\]\((?:[^()]|\([^()]*\))*\)');
final RegExp _link = RegExp(r'\[([^\]]+)\]\((?:[^()]|\([^()]*\))*\)');
final RegExp _strong = RegExp(
  r'\*\*(?=\S)(.+?)(?<=\S)\*\*|(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)',
);
final RegExp _emphasis = RegExp(
  r'(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])|'
  r'(?<!\w)_(?=[^\s_])(.+?)(?<=[^\s_])_(?!\w)',
);
final RegExp _spaces = RegExp(r'\s+');

const int _shelter = 0xE000;

String _inline(String text) => _restore(
  _collapse(
    text
        .replaceAllMapped(_codeSpan, (match) => _protect(_codeText(match[2]!)))
        .replaceAllMapped(_escape, (match) => _protect(match[1]!))
        .replaceAllMapped(_autolink, (match) => _protect(match[1]!))
        .replaceAllMapped(_image, (match) => match[1]!)
        .replaceAllMapped(_link, (match) => match[1]!)
        .replaceAllMapped(_strong, (match) => match[1] ?? match[2]!)
        .replaceAllMapped(_emphasis, (match) => match[1] ?? match[2]!),
  ),
);

String _codeText(String code) =>
    code.length > 2 &&
        code.startsWith(' ') &&
        code.endsWith(' ') &&
        code.trim().isNotEmpty
    ? code.substring(1, code.length - 1)
    : code;

String _protect(String text) => String.fromCharCodes(
  text.codeUnits.map((unit) => unit < 0x80 ? _shelter + unit : unit),
);

String _restore(String text) => String.fromCharCodes(
  text.codeUnits.map(
    (unit) =>
        unit >= _shelter && unit < _shelter + 0x80 ? unit - _shelter : unit,
  ),
);

String _collapse(String text) => text.replaceAll(_spaces, ' ').trim();
