import 'package:flutter_test/flutter_test.dart';
import 'package:shahin_app/main.dart';

void main() {
  testWidgets('Shahin app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShahinApp());
    expect(find.text('جاري التحميل...'), findsOneWidget);
  });
}
