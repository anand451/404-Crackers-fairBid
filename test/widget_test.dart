import 'package:flutter_test/flutter_test.dart';

import 'package:fairbid/main.dart';

void main() {
  testWidgets('shows Firebase setup guidance when bootstrap fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const FairBidApp(firebaseInitializationError: 'Test setup error'),
    );

    expect(find.text('Firebase needs to be configured'), findsOneWidget);
    expect(find.textContaining('flutterfire configure'), findsOneWidget);
  });
}
