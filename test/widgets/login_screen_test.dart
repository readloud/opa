import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opa_app/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    
    // Verify title
    expect(find.text('Oil Palm Assistant'), findsOneWidget);
    
    // Verify input field
    expect(find.byType(TextField), findsOneWidget);
    
    // Verify button
    expect(find.text('Kirim OTP'), findsOneWidget);
  });
  
  testWidgets('Shows error when identifier is empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    
    // Tap button without entering text
    await tester.tap(find.text('Kirim OTP'));
    await tester.pump();
    
    // Verify error message
    expect(find.text('Masukkan nomor HP atau email'), findsOneWidget);
  });
}