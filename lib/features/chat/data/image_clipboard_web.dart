import '../../../core/errors/app_exception.dart';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

@JS('navigator.clipboard.write')
external JSFunction? get _write;
@JS('navigator.clipboard')
external JSObject? get _clipboard;
@JS('window.ClipboardItem')
external JSFunction? get _itemConstructor;
@JS('ClipboardItem')
extension type _ClipboardItem._(JSObject _) implements JSObject {
  external factory _ClipboardItem(JSObject data);
}
@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny?> parts, JSObject options);
}

Future<bool> copyImage(
  Future<Uint8List> Function() download, {
  String? caption,
}) async {
  if (_clipboard == null || _itemConstructor == null || _write == null) {
    return false;
  }
  Future<JSObject> png() async {
    final codec = await ui.instantiateImageCodec(await download());
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data == null) throw StateError('Image unavailable');
    return _Blob(
      [data.buffer.asUint8List().toJS].toJS,
      {'type': 'image/png'}.jsify()! as JSObject,
    );
  }

  // Start clipboard.write within the user gesture; Safari can await the PNG Blob.
  final items = <String, JSAny?>{'image/png': png().toJS};
  if (caption?.isNotEmpty == true) {
    items['text/plain'] = _Blob(
      [caption!.toJS].toJS,
      {'type': 'text/plain'}.jsify()! as JSObject,
    );
  }
  final result =
      _write!.callAsFunction(
            _clipboard,
            [_ClipboardItem(items.jsify()! as JSObject)].toJS,
          )
          as JSPromise<JSAny?>;
  try {
    await result.toDart;
  } catch (_) {
    throw const AppException(
      'Photo could not be copied. Allow clipboard access in your browser, or open the photo to view it.',
    );
  }
  return true;
}
