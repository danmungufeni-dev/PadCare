import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A single message in the PadCare AI Health & Hygiene conversation
class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isOfflineFallback;
  final List<String>? actionSuggestions;
  final String? relatedAction; // 'find_pads' | 'cycle_tracker' | 'emergency_sos' | 'learn'

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isOfflineFallback = false,
    this.actionSuggestions,
    this.relatedAction,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'isOfflineFallback': isOfflineFallback,
        'actionSuggestions': actionSuggestions,
        'relatedAction': relatedAction,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] as String? ?? UniqueKey().toString(),
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isOfflineFallback: json['isOfflineFallback'] as bool? ?? false,
      actionSuggestions: (json['actionSuggestions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      relatedAction: json['relatedAction'] as String?,
    );
  }
}

/// Service managing confidential AI health and hygiene guidance for PadCare.
/// Integrates with Google Gemini API when online, and features a comprehensive
/// culturally aware local clinical knowledge base for 100% offline reliability.
class AiAssistantService {
  static const String _storageKey = 'padcare_ai_chat_history_v1';
  static const String _apiKeyPrefKey = 'padcare_gemini_api_key';

  static const String _systemPrompt = '''
You are "PadCare Companion", a warm, empathetic, confidential, and culturally sensitive menstrual health and hygiene counselor for adolescent girls, students, mothers, and school matrons in Uganda (specifically West Nile and Arua district).

Your role:
- Provide confidential, friendly, stigma-free guidance on menstrual hygiene, cramps, cycle tracking, puberty, nutrition, and sanitary pad care.
- Address the user warmly ("my sister", "my friend").
- Give practical, community-friendly advice suitable for Ugandan schools and communities (e.g. clean boiled water, mild soap, sun-drying reusable pads, visiting school matrons, picking up emergency pads from PadCare distribution centers).
- NEVER prescribe medications or make dangerous medical diagnoses.
- If severe symptoms (extreme unmanageable pelvic pain, high fever, soaking a pad in under an hour, foul-smelling discharge) are described, gently but firmly advise seeing a school nurse, matron, or clinic doctor immediately.
- Use clear bullet points and short, comforting paragraphs.
''';

  /// In-memory mock response for tests
  @visibleForTesting
  static String? testMockResponse;

  /// Retrieves the stored Gemini API key (from env, SharedPreferences, or null)
  static Future<String?> getApiKey() async {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_apiKeyPrefKey);
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    return null;
  }

  /// Sets or updates user-configured Gemini API key
  static Future<void> setApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefKey, key.trim());
    } catch (_) {}
  }

  /// Loads locally persisted chat history for confidentiality and continuity
  static Future<List<AiChatMessage>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((item) => AiChatMessage.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading AI chat history: $e');
    }
    return [getWelcomeMessage()];
  }

  /// Saves chat history to device local storage
  static Future<void> saveChatHistory(List<AiChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('Error saving AI chat history: $e');
    }
  }

  /// Clears the entire chat history for privacy
  static Future<void> clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  /// Initial welcoming greeting from PadCare Companion
  static AiChatMessage getWelcomeMessage() {
    return AiChatMessage(
      id: 'welcome-001',
      text: "Hello, my sister! 🌸 I am your **PadCare Companion**—your confidential, stigma-free guide for menstrual health, hygiene, and body care.\n\n"
          "You can ask me anything about period pain, cycle changes, hygiene, or where to get pads in complete privacy.\n\n"
          "*Note: I am an educational guide, not a medical doctor. For urgent severe pain or medical conditions, always reach out to a health center or school matron.*",
      isUser: false,
      timestamp: DateTime.now(),
      actionSuggestions: [
        'How do I relieve severe cramps?',
        'Period started at school, what do I do?',
        'How often should I change my pad?',
        'How do I care for reusable pads?',
        'Where can I get emergency pads?',
      ],
    );
  }

  /// Generates a response to a user question using Gemini API with intelligent offline fallback
  static Future<AiChatMessage> askCompanion(
    String userQuery, {
    List<AiChatMessage> previousMessages = const [],
  }) async {
    final cleanQuery = userQuery.trim();
    if (cleanQuery.isEmpty) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "Please type or select a question, my friend. I'm here to help you!",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    if (testMockResponse != null) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: testMockResponse!,
        isUser: false,
        timestamp: DateTime.now(),
      );
    }

    // Try online Gemini API first if configured
    final apiKey = await getApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final onlineAnswer = await _queryGeminiApi(cleanQuery, apiKey, previousMessages);
        if (onlineAnswer != null && onlineAnswer.trim().isNotEmpty) {
          final related = _detectRelatedAction(cleanQuery);
          final suggestions = _generateContextualSuggestions(cleanQuery);
          return AiChatMessage(
            id: UniqueKey().toString(),
            text: onlineAnswer.trim(),
            isUser: false,
            timestamp: DateTime.now(),
            isOfflineFallback: false,
            relatedAction: related,
            actionSuggestions: suggestions,
          );
        }
      } catch (e) {
        debugPrint('Gemini online API error, switching to offline engine: $e');
      }
    }

    // High-fidelity local offline knowledge base
    return _generateOfflineResponse(cleanQuery);
  }

  /// Calls Google Gemini 1.5 Flash endpoint via REST
  static Future<String?> _queryGeminiApi(
    String query,
    String apiKey,
    List<AiChatMessage> history,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    // Format conversation contents
    final contents = <Map<String, dynamic>>[];

    // Add recent history (up to last 6 messages)
    final recentHistory = history.length > 6
        ? history.sublist(history.length - 6)
        : history;

    for (final msg in recentHistory) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    // Append current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': query}
      ],
    });

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
        'topP': 0.95,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return text;
          }
        }
      }
    } else {
      debugPrint('Gemini HTTP ${response.statusCode}: ${response.body}');
    }
    return null;
  }

  /// Comprehensive offline knowledge base for rural settings and offline demos
  static AiChatMessage _generateOfflineResponse(String query) {
    final lower = query.toLowerCase();
    final related = _detectRelatedAction(lower);
    final suggestions = _generateContextualSuggestions(lower);

    // 1. Period Cramps & Pain Management
    if (lower.contains('cramp') ||
        lower.contains('pain') ||
        lower.contains('hurt') ||
        lower.contains('ache') ||
        lower.contains('stomach') ||
        lower.contains('back pain') ||
        lower.contains('dysmenorrhea')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "🌸 **Relieving Period Cramps & Pains**\n\n"
            "Period cramps (dysmenorrhea) are normal as your uterus contracts to shed its lining. Here are gentle, effective remedies you can use right away:\n\n"
            "• **Warm Compress**: Place a hot water bottle, warm damp cloth, or heated salt-cloth against your lower abdomen or lower back to relax muscle spasms.\n"
            "• **Gentle Movement**: Light walking or gentle pelvic stretches increase blood circulation and reduce cramping tension.\n"
            "• **Hydration & Warm Fluids**: Sip warm boiled water, ginger tea, or lemongrass infusion to ease bloating.\n"
            "• **Rest Position**: Lie on your side with your knees bent toward your chest (fetal position) to relieve pressure on abdominal muscles.\n\n"
            "⚠️ **When to seek help**: If pain is so extreme that you cannot walk or stand, or if pain is accompanied by fever or severe vomiting, visit your school nurse or nearest health center.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: related,
        actionSuggestions: suggestions,
      );
    }

    // 2. School Emergencies & Starting unexpectedly
    if (lower.contains('school') ||
        lower.contains('class') ||
        lower.contains('started') ||
        lower.contains('accident') ||
        lower.contains('stain') ||
        lower.contains('bleed') ||
        lower.contains('uniform') ||
        lower.contains('emergency')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "🎒 **Period Started at School? Do Not Worry!**\n\n"
            "First, take a deep breath. Menstruation is natural and this happens to almost every girl and teacher!\n\n"
            "1. **Cover your uniform**: Tie your school sweater, jacket, or kitenge cloth around your waist.\n"
            "2. **Excuse yourself quietly**: Ask your teacher to visit the washroom without drawing attention.\n"
            "3. **Ask the School Matron or Senior Woman Teacher**: PadCare partner schools keep emergency sanitary pads in the staffroom or matron's office.\n"
            "4. **Emergency Pad in PadCare**: You can also use PadCare to trigger an emergency pickup from the nearest school or health dispensing point.\n\n"
            "Stay confident—you are safe and supported!",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: 'find_pads',
        actionSuggestions: [
          'Where is the nearest pad dispensing point?',
          'How do I wash blood stains out of my uniform?',
          'How often should I change pads at school?',
        ],
      );
    }

    // 3. Caring for Reusable Sanitary Pads (prioritized before general hygiene)
    if (lower.contains('reusable') ||
        lower.contains('cloth') ||
        lower.contains('wash pad') ||
        lower.contains('dry') ||
        lower.contains('sun') ||
        lower.contains('kit')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "🌿 **How to Wash & Care for Reusable Pads**\n\n"
            "PadCare reusable pads are durable, eco-friendly, and last up to 12 months when washed properly:\n\n"
            "1. **Pre-Soak in Cold Water**: Soak used pads in cold water for 15-30 minutes. *Never use hot water first*, as heat bakes blood into the fabric.\n"
            "2. **Wash with Mild Soap**: Scrub gently with bar soap or laundry soap until all stains disappear.\n"
            "3. **Rinse Thoroughly**: Rinse with clean water until there are no soap bubbles left.\n"
            "4. **Dry in Direct Sunlight**: Hang them outside in direct sun! Natural UV sunlight is a powerful, natural disinfectant.\n"
            "5. **Store Dry**: Make sure the pad is 100% bone-dry before storing in a clean, breathable bag.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: related,
        actionSuggestions: suggestions,
      );
    }

    // 4. Hygiene & Pad Changing Frequency
    if (lower.contains('how often') ||
        lower.contains('change') ||
        lower.contains('hours') ||
        lower.contains('odor') ||
        lower.contains('smell') ||
        lower.contains('hygiene') ||
        lower.contains('wash intimate') ||
        lower.contains('clean hands')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "🕒 **Sanitary Pad Hygiene & Changing Best Practices**\n\n"
            "Good menstrual hygiene protects your reproductive health and keeps you feeling fresh and confident:\n\n"
            "• **Changing Frequency**: Change your disposable or reusable pad **every 4 to 6 hours**, even on light flow days. Bacteria multiply in damp blood.\n"
            "• **Clean Hands**: Always wash your hands with clean water and soap *before* and *after* handling any pad.\n"
            "• **Gentle Cleaning**: Clean your intimate area gently from front to back with clean water. Avoid perfumed soaps or harsh detergents, which cause irritation and bacterial imbalance.\n"
            "• **Safe Disposal**: Wrap used disposable pads in scrap paper and discard in the school incinerator or waste bin. Never flush pads down latrines or toilets as they cause blockages.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: related,
        actionSuggestions: suggestions,
      );
    }

    // 5. Irregular Periods & Menstrual Cycle
    if (lower.contains('irregular') ||
        lower.contains('late') ||
        lower.contains('missed') ||
        lower.contains('early') ||
        lower.contains('cycle') ||
        lower.contains('normal') ||
        lower.contains('puberty')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "📅 **Understanding Your Menstrual Cycle & Irregularities**\n\n"
            "Every girl's body is unique, especially during teenage years and puberty:\n\n"
            "• **Typical Cycle Length**: A normal cycle ranges between 21 and 35 days (counting from Day 1 of one period to Day 1 of the next).\n"
            "• **Why cycles are irregular in teens**: For the first 1 to 2 years after starting your period (menarche), your hormones are still balancing out. It is very common to have an early or late period.\n"
            "• **Common triggers**: Exam stress, illness, poor diet, strenuous sports, or sudden weight changes can temporarily delay your period.\n"
            "• **Tracking**: Use the PadCare Cycle Tracker on your Home tab to log your dates so you can anticipate your next cycle.\n\n"
            "ℹ️ If your period is missing for more than 3 consecutive months, consult a health officer or doctor.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: 'cycle_tracker',
        actionSuggestions: [
          'How do I track my cycle in PadCare?',
          'What foods help keep periods regular?',
          'What should I pack in my school hygiene bag?',
        ],
      );
    }

    // 6. Infections, Odor, Itching & Warning Signs
    if (lower.contains('itch') ||
        lower.contains('burn') ||
        lower.contains('odor') ||
        lower.contains('discharge') ||
        lower.contains('infection') ||
        lower.contains('rash') ||
        lower.contains('yeast')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "⚠️ **Infections, Itching & Body Signs**\n\n"
            "Your body gives you signals when something needs attention. Here is what you should know:\n\n"
            "• **Normal Discharge**: Clear or whitish discharge without strong smell is healthy and keeps the vagina clean.\n"
            "• **Warning Signs**: Intense itching, burning during urination, cottage-cheese-like white discharge, or strong foul-smelling green/grey fluid indicates a common infection (like yeast or bacterial vaginosis).\n"
            "• **Hygiene Tips**: Avoid perfumed body sprays or douching. Wear loose, breathable cotton underwear. Wash with plain water only.\n"
            "• **Medical Care**: Do not feel ashamed! Infections are very common and easily treated. Visit your school nurse or nearest clinic for proper medication.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: related,
        actionSuggestions: suggestions,
      );
    }

    // 7. Nutrition, Diet & Fighting Fatigue
    if (lower.contains('food') ||
        lower.contains('eat') ||
        lower.contains('diet') ||
        lower.contains('iron') ||
        lower.contains('dizzy') ||
        lower.contains('tired') ||
        lower.contains('energy') ||
        lower.contains('blood')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "🥗 **Nutrition & Energy During Your Period**\n\n"
            "When you menstruate, your body loses blood and iron. Eating the right local Ugandan foods helps fight fatigue and weakness:\n\n"
            "• **Iron-Rich Foods**: Dark green leafy vegetables (dodo, nakati, sukuma wiki), beans, peas, cowpeas, groundnuts, eggs, and millet porridge.\n"
            "• **Vitamin C for Iron Absorption**: Pair iron foods with oranges, mangoes, or lemon water—Vitamin C boosts how much iron your body absorbs.\n"
            "• **Plenty of Clean Water**: Drink at least 6 to 8 cups of clean boiled water daily to prevent headaches and bloating.\n"
            "• **Foods to Minimize**: Heavy oily foods and excess refined sugar, which can worsen mood swings and inflammation.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: related,
        actionSuggestions: suggestions,
      );
    }

    // 8. Where to get pads & distribution
    if (lower.contains('where') ||
        lower.contains('get pad') ||
        lower.contains('buy') ||
        lower.contains('cost') ||
        lower.contains('pickup') ||
        lower.contains('dispense') ||
        lower.contains('free')) {
      return AiChatMessage(
        id: UniqueKey().toString(),
        text: "📍 **How to Get Pads Through PadCare**\n\n"
            "PadCare partners with schools, hospitals, and community dispensing centers across Arua and the West Nile region:\n\n"
            "• **Free School Emergency Pads**: Available from designated senior teachers and matrons at registered schools.\n"
            "• **1-Tap 'Find Pads' Map**: Tap the **Find Pads** tab at the bottom of your screen to see verified centers with live stock indicators.\n"
            "• **Request PIN**: You can generate a private pickup PIN in the app and collect your sanitary hygiene kit without awkward questions.\n"
            "• **Emergency SOS**: If stranded without a pad, use the Emergency Pad Request to alert nearby distribution points.",
        isUser: false,
        timestamp: DateTime.now(),
        isOfflineFallback: true,
        relatedAction: 'find_pads',
        actionSuggestions: [
          'How do I request pads using a PIN?',
          'What schools in Arua have pads in stock?',
          'How can my school register with PadCare?',
        ],
      );
    }

    // 9. Default Empathetic Guidance
    return AiChatMessage(
      id: UniqueKey().toString(),
      text: "Thank you for asking, my sister! 🌸\n\n"
          "Your menstrual health and well-being matter deeply. In PadCare, every question is treated with complete privacy and zero judgment.\n\n"
          "Here are key essentials to keep in mind:\n"
          "• Change your sanitary pad every 4 to 6 hours for optimal hygiene.\n"
          "• Wash your hands with clean water and soap before and after changes.\n"
          "• Stay hydrated with boiled water and rest when cramps feel overwhelming.\n"
          "• Keep emergency supplies in your school bag (clean pad + small plastic bag).\n\n"
          "What specific topic would you like to explore further?",
      isUser: false,
      timestamp: DateTime.now(),
      isOfflineFallback: true,
      relatedAction: related,
      actionSuggestions: [
        'How do I relieve severe cramps?',
        'Period started at school, what do I do?',
        'How often should I change my pad?',
        'How to clean reusable pads properly?',
        'Where can I find free emergency pads?',
      ],
    );
  }

  /// Detects whether the query corresponds to an in-app feature button
  static String? _detectRelatedAction(String query) {
    if (query.contains('find') ||
        query.contains('where') ||
        query.contains('center') ||
        query.contains('emergency pad') ||
        query.contains('pickup') ||
        query.contains('school')) {
      return 'find_pads';
    }
    if (query.contains('cycle') ||
        query.contains('track') ||
        query.contains('calendar') ||
        query.contains('date') ||
        query.contains('late')) {
      return 'cycle_tracker';
    }
    if (query.contains('learn') ||
        query.contains('article') ||
        query.contains('guide') ||
        query.contains('read')) {
      return 'learn';
    }
    return null;
  }

  /// Generates contextual follow-up chips
  static List<String> _generateContextualSuggestions(String query) {
    if (query.contains('cramp') || query.contains('pain')) {
      return [
        'What foods help ease cramps?',
        'Can I do exercise on my period?',
        'When should I see a doctor for cramps?',
      ];
    }
    if (query.contains('reusable')) {
      return [
        'How long do reusable pads last?',
        'Can I dry reusable pads indoors?',
        'How many reusable pads do I need?',
      ];
    }
    return [
      'How do I relieve severe cramps?',
      'How often should I change my pad?',
      'Where can I get emergency pads?',
      'What foods give me energy on my period?',
    ];
  }
}
