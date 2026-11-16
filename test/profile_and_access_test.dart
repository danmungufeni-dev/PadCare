import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padcare/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile and Access Screen Updates', () {
    testWidgets(
      'tapping profile in top bar navigates to profile page and does not log user out',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        bool signedOut = false;

        await tester.pumpWidget(
          MaterialApp(
            home: ParentHomeScreen(
              parentName: 'Amina Nakato',
              onSignOut: () => signedOut = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially on Home tab (index 0)
        expect(find.text('Pickup support near you'), findsOneWidget);
        expect(signedOut, isFalse);

        // Tap the profile avatar in the top bar
        final profileNavFinder = find.byKey(const ValueKey('profile-nav-btn'));
        expect(profileNavFinder, findsOneWidget);
        await tester.tap(profileNavFinder);
        await tester.pumpAndSettle();

        // User MUST NOT be logged out!
        expect(signedOut, isFalse);

        // User should now be on the Profile & Access page!
        expect(find.text('Profile & Access'), findsOneWidget);
        expect(find.text('SETTINGS & ACCOUNT'), findsOneWidget);
        expect(find.text('Individual & Community Access'), findsOneWidget);
      },
    );

    testWidgets(
      'PadCare Security & Auth Suite is removed from Profile and Access page',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          MaterialApp(
            home: ParentHomeScreen(
              parentName: 'Amina Nakato',
              onSignOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Profile page
        await tester.tap(find.byKey(const ValueKey('profile-nav-btn')));
        await tester.pumpAndSettle();

        // Verify "PadCare Security & Auth Suite" is NOT found on Profile page
        expect(find.textContaining('PadCare Security & Auth Suite'), findsNothing);
        expect(find.textContaining('Authentication Suite'), findsNothing);
        expect(find.textContaining('PIN lock, Biometrics, 2FA'), findsNothing);
      },
    );

    testWidgets(
      'individual can view and edit their personal details on Profile page',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'padher_user_name': 'Amina Nakato',
          'padher_user_phone': '+256 772 111 222',
          'padher_user_email': 'amina@gmail.com',
          'padher_user_subcounty': 'Ediofe',
          'padher_emergency_contact': 'Mama Amina',
          'padher_emergency_phone': '+256 701 333 444',
          'padher_preferred_school': 'Ediofe Girls School',
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ParentHomeScreen(
              parentName: 'Amina Nakato',
              onSignOut: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Profile page
        await tester.tap(find.byKey(const ValueKey('profile-nav-btn')));
        await tester.pumpAndSettle();

        // Verify initial details from SharedPreferences
        expect(find.text('Amina Nakato'), findsWidgets);
        expect(find.text('+256 772 111 222'), findsOneWidget);
        expect(find.text('amina@gmail.com'), findsOneWidget);
        expect(find.text('Ediofe'), findsWidgets);
        expect(find.text('Ediofe Girls School'), findsWidgets);

        // Tap "Add or Update Personal Details" button
        final editDetailsBtn = find.byKey(const ValueKey('edit-details-btn'));
        await tester.ensureVisible(editDetailsBtn);
        await tester.tap(editDetailsBtn);
        await tester.pumpAndSettle();

        // Edit personal details modal is opened
        expect(find.text('Edit Personal Details'), findsOneWidget);

        // Change name, phone, email, and emergency contact
        final nameField = find.byKey(const ValueKey('edit-individual-name-field'));
        final phoneField = find.byKey(const ValueKey('edit-individual-phone-field'));
        final emailField = find.byKey(const ValueKey('edit-individual-email-field'));

        await tester.enterText(nameField, 'Amina Grace Nakato');
        await tester.enterText(phoneField, '+256 788 999 000');
        await tester.enterText(emailField, 'amina.grace@example.com');

        // Tap Save Details
        final saveBtn = find.byKey(const ValueKey('save-individual-details-btn'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // Modal closed and success SnackBar shown
        expect(find.text('Profile details updated successfully!'), findsOneWidget);

        // Updated details displayed on Profile page
        expect(find.text('Amina Grace Nakato'), findsWidgets);
        expect(find.text('+256 788 999 000'), findsOneWidget);
        expect(find.text('amina.grace@example.com'), findsOneWidget);

        // Verify persisted to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('padher_user_name'), 'Amina Grace Nakato');
        expect(prefs.getString('padher_user_phone'), '+256 788 999 000');
        expect(prefs.getString('padher_user_email'), 'amina.grace@example.com');
      },
    );

    testWidgets(
      'access screen allows individual to enter contact details when registering',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Choose Parent or guardian role
        await tester.tap(find.text('Parent or guardian'));
        await tester.pumpAndSettle();

        expect(find.text('Parent preview'), findsOneWidget);

        // Tap "Set a display name" to reveal full details form
        await tester.tap(find.text('Set a display name'));
        await tester.pumpAndSettle();

        // Enter display name, phone, and submit
        await tester.enterText(
          find.byKey(const ValueKey('account-name')),
          'Zainab Bako',
        );
        await tester.enterText(
          find.byKey(const ValueKey('account-phone')),
          '+256 750 123 456',
        );

        await tester.ensureVisible(find.byKey(const ValueKey('submit-access')));
        await tester.tap(find.byKey(const ValueKey('submit-access')));
        await tester.pumpAndSettle();

        // Verify inside ParentHomeScreen
        expect(find.text('Pickup support near you'), findsOneWidget);

        // Navigate to Profile & Access page
        await tester.tap(find.byKey(const ValueKey('profile-nav-btn')));
        await tester.pumpAndSettle();

        // Verify name and phone were passed and displayed
        expect(find.text('Zainab Bako'), findsWidgets);
        expect(find.text('+256 750 123 456'), findsOneWidget);
      },
    );
  });
}
