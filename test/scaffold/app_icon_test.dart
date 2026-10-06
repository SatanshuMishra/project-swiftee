import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const appIconSetDirectory = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const windowsIconPath = 'windows/runner/resources/app_icon.ico';

const macosCanvas = 1024;
const macosSquareOrigin = 100;
const macosUnitsToCanvas = 8.24;
const windowsUnitsPerSide = 100;

const staffProbeUnits = (x: 15, y: 30);
const macosBackgroundProbe = (x: 512, y: 860);

const icoSizes = [16, 24, 32, 48, 64, 128, 256];
const largestSmallArtwork = 32;

typedef Rgba = ({int r, int g, int b, int a});

Future<ui.Image> decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Rgba> pixelAt(ui.Image image, ({int x, int y}) point) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final offset = (point.y * image.width + point.x) * 4;
  return (
    r: data!.getUint8(offset),
    g: data.getUint8(offset + 1),
    b: data.getUint8(offset + 2),
    a: data.getUint8(offset + 3),
  );
}

bool isOpaqueColor(Rgba pixel, int r, int g, int b) =>
    pixel.a == 255 &&
    (pixel.r - r).abs() <= 3 &&
    (pixel.g - g).abs() <= 3 &&
    (pixel.b - b).abs() <= 3;

bool isCocoa(Rgba pixel) => isOpaqueColor(pixel, 0x3B, 0x2F, 0x2F);

bool isStaffOnCocoa(Rgba pixel) => isOpaqueColor(pixel, 107, 94, 90);

({int x, int y}) macosStaffProbe(int size) {
  int toPixel(int units) =>
      ((macosSquareOrigin + macosUnitsToCanvas * units) * size / macosCanvas)
          .floor();
  return (x: toPixel(staffProbeUnits.x), y: toPixel(staffProbeUnits.y));
}

({int x, int y}) windowsStaffProbe(int size) => (
  x: staffProbeUnits.x * size ~/ windowsUnitsPerSide,
  y: staffProbeUnits.y * size ~/ windowsUnitsPerSide,
);

int slotPoints(Map<String, Object?> slot) =>
    int.parse((slot['size']! as String).split('x').first);

int slotPixels(Map<String, Object?> slot) =>
    slotPoints(slot) *
    int.parse((slot['scale']! as String).replaceAll('x', ''));

typedef IcoEntry = ({int width, int height, Uint8List data});

IcoEntry readIcoEntry(Uint8List bytes, ByteData view, int index) {
  final entry = 6 + 16 * index;
  int dimension(int stored) => stored == 0 ? 256 : stored;
  final length = view.getUint32(entry + 8, Endian.little);
  final offset = view.getUint32(entry + 12, Endian.little);
  return (
    width: dimension(view.getUint8(entry)),
    height: dimension(view.getUint8(entry + 1)),
    data: Uint8List.sublistView(bytes, offset, offset + length),
  );
}

List<IcoEntry> readIcoDirectory(Uint8List bytes) {
  final view = ByteData.sublistView(bytes);
  expect(view.getUint16(0, Endian.little), 0);
  expect(view.getUint16(2, Endian.little), 1);
  return [
    for (var index = 0; index < view.getUint16(4, Endian.little); index++)
      readIcoEntry(bytes, view, index),
  ];
}

const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  group('platform icons are the misu cat-note', () {
    test('every macOS icon slot holds a png of its declared size, '
        'without the staff at 16 and 32 pt and with it above', () async {
      final contents = jsonDecode(
        File(p.join(appIconSetDirectory, 'Contents.json')).readAsStringSync(),
      ) as Map<String, Object?>;
      final slots = (contents['images']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(slots, hasLength(10));

      final pngFiles = Directory(appIconSetDirectory)
          .listSync()
          .map((entry) => p.basename(entry.path))
          .where((name) => name.endsWith('.png'))
          .toSet();
      expect(
        slots.map((slot) => slot['filename']).toSet(),
        pngFiles,
        reason: 'every png in the icon set is assigned to a slot',
      );

      for (final slot in slots) {
        final pixels = slotPixels(slot);
        final image = await decodePng(
          File(p.join(appIconSetDirectory, slot['filename']! as String))
              .readAsBytesSync(),
        );
        expect(
          (image.width, image.height),
          (pixels, pixels),
          reason: '${slot['size']} @${slot['scale']}',
        );
        final staffPixel = await pixelAt(image, macosStaffProbe(pixels));
        expect(
          isCocoa(staffPixel),
          slotPoints(slot) <= largestSmallArtwork,
          reason:
              '${slot['size']} @${slot['scale']} staff probe $staffPixel '
              'small artwork expected: '
              '${slotPoints(slot) <= largestSmallArtwork}',
        );
        image.dispose();
      }
    });

    test('the 1024 icon is a cocoa rounded square with a solid staff on a '
        'transparent canvas', () async {
      final image = await decodePng(
        File(p.join(appIconSetDirectory, 'app_icon_1024.png'))
            .readAsBytesSync(),
      );
      expect((image.width, image.height), (1024, 1024));
      expect((await pixelAt(image, (x: 0, y: 0))).a, 0);
      final background = await pixelAt(image, macosBackgroundProbe);
      expect(isCocoa(background), isTrue, reason: '$background');
      final staff = await pixelAt(image, macosStaffProbe(1024));
      expect(isStaffOnCocoa(staff), isTrue, reason: '$staff');
      image.dispose();
    });

    test('app_icon.ico holds png images at 16, 24, 32, 48, 64, 128 and '
        '256 px, without the staff up to 32 px', () async {
      final entries = readIcoDirectory(File(windowsIconPath).readAsBytesSync());
      expect(entries.map((entry) => entry.width).toList(), icoSizes);

      for (final entry in entries) {
        expect(entry.height, entry.width);
        expect(entry.data.sublist(0, 8), pngSignature);
        final image = await decodePng(entry.data);
        expect((image.width, image.height), (entry.width, entry.width));
        final staffPixel = await pixelAt(image, windowsStaffProbe(entry.width));
        expect(
          isCocoa(staffPixel),
          entry.width <= largestSmallArtwork,
          reason:
              '${entry.width} px staff probe $staffPixel small artwork '
              'expected: ${entry.width <= largestSmallArtwork}',
        );
        image.dispose();
      }
    });
  });
}
