import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/data/covers/cover_store.dart';
import 'package:swiftie_quiz/state/covers.dart';

@immutable
class CoverImage extends ImageProvider<CoverImage> {
  const CoverImage(this.url, this.store);

  final String url;
  final CoverStore store;

  @override
  Future<CoverImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CoverImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _decode(key, decode),
        scale: 1,
        debugLabel: key.url,
      );

  static Future<ui.Codec> _decode(
    CoverImage key,
    ImageDecoderCallback decode,
  ) async {
    try {
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(await key.store.load(key.url)),
      );
    } on Object {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CoverImage && other.url == url && identical(other.store, store);

  @override
  int get hashCode => Object.hash(url, identityHashCode(store));

  @override
  String toString() => 'CoverImage($url)';
}

class CoverPicture extends ConsumerWidget {
  const CoverPicture(this.url, {super.key});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Image(
    image: CoverImage(url, ref.watch(coverStoreProvider)),
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
