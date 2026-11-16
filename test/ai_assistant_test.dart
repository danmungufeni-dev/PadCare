import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:padcare/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiAssistantService.testMockResponse = null;
  });

  tearDown(() {
    AiAssistantService.testMockResponse = null;
  });

  group('AiAssistantService Offline Clinical Knowledge Tests', () {
    test('Welcome message has warm tone and action suggestions', () {
      final welcome = AiAssistantService.getWelcomeMessage();
      expect(welcome.isUser, isFalse);
      expect(welcome.text, contains('PadCare Companion'));
      expect(welcome.text, contains('confidential'));
      expect(welcome.actionSuggestions, isNotNull);
      expect(welcome.actionSuggestions!.length, greaterThanOrEqualTo(4));
    });

    test('Cramps and pain question returns practical remedies and medical warning flags', () async {
      final answer = await AiAssistantService.askCompanion('How do I relieve severe menstrual cramps?');
      expect(answer.isUser, isFalse);
      expect(answer.isOfflineFallback, isTrue);
      expect(answer.text, contains('Warm Compress'));
      expect(answer.text, contains('Hydration'));
      expect(answer.text, contains('fetal position'));
      expect(answer.text, contains('When to seek help'));
    });

    test('Period at school question returns emergency guidance and find_pads action', () async {
      final answer = await AiAssistantService.askCompanion('My period started in class at school, what should I do?');
      expect(answer.isUser, isFalse);
      expect(answer.text, contains('Cover your uniform'));
      expect(answer.text, contains('Senior Woman Teacher'));
      expect(answer.relatedAction, equals('find_pads'));
    });

    test('Hygiene and changing frequency question advises 4 to 6 hours', () async {
      final answer = await AiAssistantService.askCompanion('How often should I change my sanitary pad?');
      expect(answer.isUser, isFalse);
      expect(answer.text, contains('every 4 to 6 hours'));
      expect(answer.text, contains('Clean Hands'));
      expect(answer.text, contains('incinerator'));
    });

    test('Reusable pad care question specifies cold water pre-soak and direct sunlight drying', () async {
      final answer = await AiAssistantService.askCompanion('How do I wash and care for reusable pads?');
      expect(answer.isUser, isFalse);
      expect(answer.text, contains('Cold Water'));
      expect(answer.text, contains('Direct Sunlight'));
      expect(answer.text, contains('natural disinfectant'));
    });

    test('Cycle length question returns 21-35 days and cycle tracker action', () async {
      final answer = await AiAssistantService.askCompanion('Is my menstrual cycle normal or irregular?');
      expect(answer.isUser, isFalse);
      expect(answer.text, contains('21 and 35 days'));
      expect(answer.text, contains('teen'));
      expect(answer.relatedAction, equals('cycle_tracker'));
    });

    test('Nutrition question returns local Ugandan iron-rich foods (dodo, nakati, beans)', () async {
      final answer = await AiAssistantService.askCompanion('What foods should I eat during my period to stay strong?');
      expect(answer.isUser, isFalse);
      expect(answer.text, contains('dodo'));
      expect(answer.text, contains('Iron-Rich Foods'));
      expect(answer.text, contains('Vitamin C'));
    });

    test('Chat history persists to local storage and can be cleared privately', () async {
      final messages = [
        AiAssistantService.getWelcomeMessage(),
        AiChatMessage(
          id: 'test-1',
          text: 'How to relieve pain?',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ];

      await AiAssistantService.saveChatHistory(messages);
      final loaded = await AiAssistantService.loadChatHistory();
      expect(loaded.length, equals(2));
      expect(loaded[1].text, equals('How to relieve pain?'));

      await AiAssistantService.clearChatHistory();
      final reset = await AiAssistantService.loadChatHistory();
      expect(reset.length, equals(1)); // returns fresh welcome message
    });

    test('API key can be saved and retrieved', () async {
      await AiAssistantService.setApiKey('test-key-12345');
      final key = await AiAssistantService.getApiKey();
      expect(key, equals('test-key-12345'));
    });
  });

  group('AiAssistantScreen Widget Tests', () {
    testWidgets('AiAssistantScreen renders header, confidentiality banner, and welcome message', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PadCare Companion'), findsWidgets);
      expect(find.textContaining('100% Confidential'), findsWidgets);
      expect(find.textContaining('educational guide, not a medical doctor'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('User can send a question and receive offline companion response', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'How to stop cramps?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Relieving Period Cramps'), findsOneWidget);
    });

    testWidgets('Tapping action chip populates and sends query automatically', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on one of the quick question chips
      final chip = find.text('How do I relieve severe cramps?');
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.textContaining('Relieving Period Cramps'), findsOneWidget);
    });

    testWidgets('Tapping Find Pads button triggers onFindPadsRequested callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);

      bool findPadsCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantScreen(
            onFindPadsRequested: () => findPadsCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'Where can I get emergency pads at school?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      final actionButton = find.text('Find Pads Near Me');
      expect(actionButton, findsOneWidget);
      await tester.tap(actionButton);
      await tester.pumpAndSettle();

      expect(findPadsCalled, isTrue);
    });

    testWidgets('Clear chat icon displays confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AiAssistantScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Clear Chat History?'), findsOneWidget);
      expect(find.text('Clear Privately'), findsOneWidget);

      await tester.tap(find.text('Clear Privately'));
      await tester.pumpAndSettle();

      // Resets to initial welcome message
      expect(find.textContaining('PadCare Companion'), findsWidgets);
      expect(find.textContaining('confidential, stigma-free guide'), findsOneWidget);
    });
  });

  group('ParentHomeScreen AI Integration Tests', () {
    testWidgets('ParentHomeScreen displays Ask AI FAB and opens companion screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ParentHomeScreen(
            parentName: 'Nicholas Acadri',
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ask AI FAB is rendered
      final askAiFab = find.byKey(const ValueKey('ask-ai-fab'));
      expect(askAiFab, findsOneWidget);

      // PadCare Companion card is rendered on Home screen
      expect(find.text('PadCare Companion'), findsWidgets);
      expect(find.text('Chat Confidentially with AI Companion'), findsOneWidget);

      // Tap FAB to open AI screen
      await tester.tap(askAiFab);
      await tester.pumpAndSettle();

      // Verify AI Companion screen opened
      expect(find.text('100% Confidential. Educational guide only—visit a clinic for medical emergencies.'), findsOneWidget);
    });
  });
}
