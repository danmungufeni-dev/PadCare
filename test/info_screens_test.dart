import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padcare/info/info_screens.dart';

void main() {
  Widget testWrapper(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35B9B4),
          brightness: Brightness.light,
        ),
      ),
      home: child,
    );
  }

  group('PadCare Information Suite', () {
    testWidgets('AboutPage renders PadCare details, terms, and privacy policy', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const AboutPage()));

      expect(find.text('About PadCare'), findsOneWidget);
      expect(find.text('PadCare'), findsOneWidget);
      expect(find.text('Version 1.0.0+1'), findsOneWidget);
      expect(
        find.textContaining('Built for Arua City & West Nile, Uganda'),
        findsOneWidget,
      );
      expect(
        find.textContaining('period poverty and classroom absenteeism'),
        findsOneWidget,
      );

      // Verify Terms of Service dialog
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.textContaining('free, community-centered humanitarian platform'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verify Privacy Policy dialog
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.textContaining('We never ask for a girl\'s name'), findsOneWidget);
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();
    });

    testWidgets('ContactPage renders required emails and phone numbers', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const ContactPage()));

      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Send Message'), findsOneWidget);

      // Verify specific required contact details
      expect(find.text('devgtnation@gmail.com'), findsOneWidget);
      expect(find.text('abetinichlas@gmail.com'), findsOneWidget);
      expect(find.text('+256 778 625 624'), findsOneWidget);
      expect(find.text('+256 783 669 967'), findsOneWidget);

      // Test validation on empty send
      await tester.tap(find.text('Send Message'));
      await tester.pump();
      expect(find.text('Please fill in your name, email, and message.'), findsOneWidget);

      // Fill in fields and send
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Amina');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'amina@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Inquiry about distribution.');
      await tester.tap(find.text('Send Message'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        find.text('Thank you! Your message has been sent to the PadCare team.'),
        findsOneWidget,
      );
    });

    testWidgets('FaqPage displays questions and expands answers', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const FaqPage()));

      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('What is PadCare and who can use it?'), findsOneWidget);
      expect(find.text('Is my pad request completely confidential?'), findsOneWidget);

      // Tap to expand first FAQ
      await tester.tap(find.text('What is PadCare and who can use it?'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('PadCare is a community-led menstrual hygiene platform'),
        findsOneWidget,
      );
    });

    testWidgets('TeamPage renders Dan Mungufeni (GTNationDEV) & Abeti Acadri Nicholas', (
      tester,
    ) async {
      await tester.pumpWidget(testWrapper(const TeamPage()));

      expect(find.text('Our Team'), findsOneWidget);
      expect(find.text('The Creators Behind PadCare'), findsOneWidget);

      // Verify requested team members
      expect(find.text('Dan Mungufeni (GTNationDEV)'), findsOneWidget);
      expect(find.text('Lead Software Engineer & Project Founder'), findsOneWidget);

      expect(find.text('Abeti Acadri Nicholas'), findsOneWidget);
      expect(find.text('Co-Founder & Operations / Community Lead'), findsOneWidget);

      // Verify contact options on cards
      expect(find.text('Email'), findsNWidgets(2));
      expect(find.text('Call'), findsNWidgets(2));
      expect(find.byIcon(Icons.chat_bubble_outline), findsNWidgets(2));
    });
  });
}
