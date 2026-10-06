import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const brandDirectory = 'assets/brand';
const appIconSetDirectory = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const windowsIconPath = 'windows/runner/resources/app_icon.ico';

typedef IconRender = ({String svg, int size});

const macosRenders = <IconRender>[
  (svg: 'app-icon-macos-small.svg', size: 16),
  (svg: 'app-icon-macos-small.svg', size: 32),
  (svg: 'app-icon-macos-small.svg', size: 64),
  (svg: 'app-icon-macos.svg', size: 128),
  (svg: 'app-icon-macos.svg', size: 256),
  (svg: 'app-icon-macos.svg', size: 512),
  (svg: 'app-icon-macos.svg', size: 1024),
];

const windowsRenders = <IconRender>[
  (svg: 'app-icon-small.svg', size: 16),
  (svg: 'app-icon-small.svg', size: 24),
  (svg: 'app-icon-small.svg', size: 32),
  (svg: 'app-icon.svg', size: 48),
  (svg: 'app-icon.svg', size: 64),
  (svg: 'app-icon.svg', size: 128),
  (svg: 'app-icon.svg', size: 256),
];

typedef IcoImage = ({int size, Uint8List png});

const icoHeaderLength = 6;
const icoEntryLength = 16;
const icoBitsPerPixel = 32;

final unfilledLine = RegExp(r'<line\b(?![^>]*\sfill=)');

String withLinesUnfilled(String svg) =>
    svg.replaceAll(unfilledLine, '<line fill="none"');

Future<Uint8List> renderPng(IconRender render) async {
  final source = File(p.join(brandDirectory, render.svg)).readAsStringSync();
  final info = await vg.loadPicture(
    SvgStringLoader(withLinesUnfilled(source)),
    null,
  );
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..scale(render.size / info.size.width, render.size / info.size.height)
    ..drawPicture(info.picture);
  final picture = recorder.endRecording();
  final image = await picture.toImage(render.size, render.size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  info.picture.dispose();
  return png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
}

Uint8List assembleIco(List<IcoImage> images) {
  final directoryLength = icoHeaderLength + icoEntryLength * images.length;
  final offsets = images.fold<List<int>>([
    directoryLength,
  ], (offsets, image) => [...offsets, offsets.last + image.png.length]);
  final directory = ByteData(directoryLength)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, images.length, Endian.little);
  for (final (index, image) in images.indexed) {
    final entry = icoHeaderLength + icoEntryLength * index;
    final dimension = image.size >= 256 ? 0 : image.size;
    directory
      ..setUint8(entry, dimension)
      ..setUint8(entry + 1, dimension)
      ..setUint8(entry + 2, 0)
      ..setUint8(entry + 3, 0)
      ..setUint16(entry + 4, 1, Endian.little)
      ..setUint16(entry + 6, icoBitsPerPixel, Endian.little)
      ..setUint32(entry + 8, image.png.length, Endian.little)
      ..setUint32(entry + 12, offsets[index], Endian.little);
  }
  return Uint8List.fromList([
    ...directory.buffer.asUint8List(),
    for (final image in images) ...image.png,
  ]);
}

void main() {
  test('renders the misu cat-note platform icons', () async {
    for (final render in macosRenders) {
      File(p.join(appIconSetDirectory, 'app_icon_${render.size}.png'))
          .writeAsBytesSync(await renderPng(render));
    }
    final windowsImages = <IcoImage>[
      for (final render in windowsRenders)
        (size: render.size, png: await renderPng(render)),
    ];
    File(windowsIconPath).writeAsBytesSync(assembleIco(windowsImages));
  });
}
