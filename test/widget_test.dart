import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascend/app/app.dart';

void main() {
  testWidgets('Ascend app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AscendApp()));
    expect(find.text('Ascend'), findsOneWidget);
  });
}
