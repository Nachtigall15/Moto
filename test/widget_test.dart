import 'package:flutter_test/flutter_test.dart';
import 'package:moto/app.dart';
import 'package:moto/features/navigation/navigation_screen.dart';

void main() {
  testWidgets('App startet mit dem Navigations-Tab', (tester) async {
    await tester.pumpWidget(const MotoApp());
    await tester.pump();

    expect(find.byType(NavigationScreen), findsOneWidget);
    expect(find.text('Route berechnen'), findsOneWidget);
  });
}
