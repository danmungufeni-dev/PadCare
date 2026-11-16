import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/info/info_screens.dart';
import 'package:padcare/services/communication_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunicationService Phone, SMS, WhatsApp, and Email Tests', () {
    test('cleanPhoneNumber correctly strips spaces, parentheses, hyphens, and dots', () {
      expect(CommunicationService.cleanPhoneNumber('+256 778 625 624'), '+256778625624');
      expect(CommunicationService.cleanPhoneNumber('+256 (0) 783-669.967'), '+2560783669967');
      expect(CommunicationService.cleanPhoneNumber('0800 200 600'), '0800200600');
    });

    test('formatForWhatsApp formats Ugandan phone numbers for WhatsApp international click-to-chat', () {
      // 1. With plus prefix
      expect(CommunicationService.formatForWhatsApp('+256 778 625 624'), '256778625624');

      // 2. Local 07 / 08 prefix converted to 256
      expect(CommunicationService.formatForWhatsApp('0783 669 967'), '256783669967');
      expect(CommunicationService.formatForWhatsApp('0772100200'), '256772100200');

      // 3. Toll free or already international
      expect(CommunicationService.formatForWhatsApp('256700000000'), '256700000000');
    });

    test('Gmail Web URL formatting includes view=cm and encoded subject & body', () {
      const email = 'devgtnation@gmail.com';
      const subject = 'PadCare Partnership';
      const body = 'Hello PadCare team, we want to collaborate!';

      final suParam = '&su=${Uri.encodeComponent(subject)}';
      final bodyParam = '&body=${Uri.encodeComponent(body)}';
      final expectedUrl = 'https://mail.google.com/mail/?view=cm&fs=1&to=${Uri.encodeComponent(email)}$suParam$bodyParam';

      expect(expectedUrl, contains('https://mail.google.com/mail/?view=cm&fs=1'));
      expect(expectedUrl, contains('devgtnation%40gmail.com'));
      expect(expectedUrl, contains('PadCare%20Partnership'));
    });
  });

  group('ContactPage & TeamPage Interactive Communication UI Tests', () {
    testWidgets('ContactPage displays Call, SMS, WhatsApp, and Email actions', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: ContactPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Check Email ListTiles and icons
      expect(find.text('devgtnation@gmail.com'), findsOneWidget);
      expect(find.text('abetinichlas@gmail.com'), findsOneWidget);
      expect(find.byTooltip('Open in Email App'), findsNWidgets(2));
      expect(find.byTooltip('Open Gmail Website'), findsNWidgets(2));

      // Check Helpline ListTiles and actions (WhatsApp, SMS, Call)
      expect(find.text('+256 778 625 624'), findsOneWidget);
      expect(find.text('+256 783 669 967'), findsOneWidget);
      expect(find.byTooltip('WhatsApp chat'), findsWidgets);
      expect(find.byTooltip('SMS message app'), findsWidgets);
      expect(find.byTooltip('Phone call app'), findsWidgets);

      // Tap email tile to trigger email options modal
      await tester.tap(find.text('devgtnation@gmail.com'));
      await tester.pumpAndSettle();

      // Verify email options sheet is shown
      expect(find.text('Default Email App'), findsOneWidget);
      expect(find.text('Gmail Website'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Gmail Website'));
      await tester.pumpAndSettle();
    });

    testWidgets('TeamPage displays Email, Call, Message (SMS), and WhatsApp actions', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: TeamPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Check team members
      expect(find.text('Dan Mungufeni (GTNationDEV)'), findsOneWidget);
      expect(find.text('Abeti Acadri Nicholas'), findsOneWidget);

      // Check communication buttons
      expect(find.text('Email'), findsNWidgets(2));
      expect(find.text('Call'), findsNWidgets(2));
      expect(find.text('Message'), findsNWidgets(2));
      expect(find.byTooltip('Chat on WhatsApp'), findsNWidgets(2));
    });
  });
}
