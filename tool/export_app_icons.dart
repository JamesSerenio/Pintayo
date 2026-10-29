// Run: flutter test tool/export_app_icons.dart
// Rasterizes the source-controlled PinTayo vector geometry for native iOS icons.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export native app icons from PinTayo vector', () async {
    final manifest = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    );
    final entries =
        (jsonDecode(await manifest.readAsString()) as Map)['images'] as List;
    for (final entry in entries) {
      final filename = entry['filename'] as String?;
      if (filename == null) continue;
      final logical = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceAll('x', ''),
      );
      final size = (logical * scale).round();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(size / 128);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 128, 128),
        ui.Paint()..color = const ui.Color(0xFFDCEFE4),
      );
      final pin = ui.Path()
        ..moveTo(64, 15)
        ..cubicTo(42, 15, 26, 31, 26, 52)
        ..cubicTo(26, 80, 64, 114, 64, 114)
        ..cubicTo(64, 114, 102, 80, 102, 52)
        ..cubicTo(102, 31, 86, 15, 64, 15)
        ..close();
      canvas.drawPath(pin, ui.Paint()..color = const ui.Color(0xFF087F6B));
      canvas.drawCircle(
        const ui.Offset(64, 52),
        15,
        ui.Paint()..color = const ui.Color(0xFFF8F8F2),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${manifest.parent.path}/$filename',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
