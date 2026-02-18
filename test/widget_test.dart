import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('shows login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyApp(
        isLoggedIn: false,
        email: '',
      ),
    );

    expect(find.text('Login'), findsOneWidget);
  });
}
