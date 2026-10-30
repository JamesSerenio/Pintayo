import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pintayo/features/chat/presentation/widgets/message_bubble.dart';
import 'package:pintayo/features/chat/presentation/widgets/image_message.dart';
import 'package:pintayo/features/chat/data/models/message.dart';
import 'package:pintayo/shared/widgets/private_image.dart';

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List bytes;
  _Response(this.bytes);
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  final Uint8List bytes;
  _Request(this.bytes);
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  final Uint8List bytes;
  _Client(this.bytes);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [const Size(80, 200), const Size(200, 80)]) {
    for (final mine in [true, false]) {
      testWidgets(
        '${mine ? 'Sent' : 'Received'} ${size.width < size.height ? 'portrait' : 'landscape'} photo keeps aspect ratio without a colored bubble',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          late Uint8List png;
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            Canvas(
              recorder,
            ).drawRect(Offset.zero & size, Paint()..color = Colors.teal);
            final picture = recorder.endRecording();
            final image = await picture.toImage(
              size.width.toInt(),
              size.height.toInt(),
            );
            png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            image.dispose();
            picture.dispose();
          });
          debugNetworkImageHttpClientProvider = () => _Client(png);
          addTearDown(() {
            debugNetworkImageHttpClientProvider = null;
            imageCache.clear();
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                signedImageProvider(('attachments', 'fixture')).overrideWith(
                  (ref) async =>
                      'https://fixture.invalid/${size.width}-${mine ? 1 : 0}.png',
                ),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: MessageBubble(
                    message: Message(
                      id: 'photo',
                      conversationId: 'chat',
                      sender: 'sender',
                      attachment: 'fixture',
                      createdAt: DateTime.now(),
                    ),
                    mine: mine,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.runAsync(() async {
            await precacheImage(
              NetworkImage(
                'https://fixture.invalid/${size.width}-${mine ? 1 : 0}.png',
              ),
              tester.element(find.byType(ImageMessage)),
            );
          });
          await tester.pumpAndSettle();
          debugNetworkImageHttpClientProvider = null;
          final image = find.descendant(
            of: find.byType(ImageMessage),
            matching: find.byType(Image),
          );
          expect(image, findsOneWidget);
          final rendered = tester.getSize(image);
          expect(
            rendered.width / rendered.height,
            closeTo(size.width / size.height, 0.01),
          );
          expect(rendered.width, lessThanOrEqualTo(300));
          expect(rendered.height, lessThanOrEqualTo(360));
          expect(tester.widget<Image>(image).fit, BoxFit.contain);
          expect(
            find.ancestor(
              of: find.byType(ImageMessage),
              matching: find.byType(DecoratedBox),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
