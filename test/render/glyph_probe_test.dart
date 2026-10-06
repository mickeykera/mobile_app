import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

final _key = GlobalKey();

Future<int> _inkPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  late int dark;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    dark = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      // opaque, non-white pixel == actual ink
      if (data.getUint8(i + 3) > 200 && data.getUint8(i) < 128) dark++;
    }
    image.dispose();
  });
  return dark;
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _key,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a Lucide glyph actually paints pixels', (tester) async {
    await tester.pumpWidget(_host(
        const Icon(LucideIcons.circleCheck, size: 64, color: Colors.black)));
    await tester.pumpAndSettle();
    expect(await _inkPixels(tester), greaterThan(20),
        reason: 'Lucide glyph produced no ink -> font not resolving');
  });

  testWidgets('a Material glyph paints, for comparison', (tester) async {
    await tester.pumpWidget(
        _host(const Icon(Icons.check, size: 64, color: Colors.black)));
    await tester.pumpAndSettle();
    expect(await _inkPixels(tester), greaterThan(20));
  });
}
