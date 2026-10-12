import 'package:flutter_test/flutter_test.dart';
import 'package:ejemplo/main.dart';

void main() {
  testWidgets('Smoke test for BiometricDemoApp', (WidgetTester tester) async {
    await tester.pumpWidget(const BiometricDemoApp());
    expect(find.text('Sensor de Huellas Digitales'), findsOneWidget);
  });
}
