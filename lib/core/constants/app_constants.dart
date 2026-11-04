/// App-wide constants for DEVA.
library;

class AppConstants {
  AppConstants._();

  // ── App identity ──────────────────────────────────────────────────────
  static const String appName = 'DEVA';
  static const String packageName = 'com.deva.assistant';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your personal AI assistant';

  // ── AI API Routing ──────────────────────────────────────────────────────
  // If you deploy the Stateless Proxy (proxy/worker.js), place the URL here.
  static const String proxyBaseUrl = '';
  static const String groqBaseUrl = 'https://openrouter.ai/api/v1';
  static const String groqModel = 'google/gemini-2.5-flash';
  static const int groqMaxTokens = 512; // Keep responses concise for TTS
  static const double groqTemp = 0.0;
  static const String privacyPolicyUrl =
      'https://deva-assistant.github.io/privacy-policy.html';

  // ── DEVA system prompt ────────────────────────────────────────────────
  static const String systemPrompt = '''
You are DEVA, an elite voice-first AI assistant modeled after JARVIS from Iron Man. You run natively on the user's Android device with full access to device controls and system actions.

CRITICAL RULES:
1. Always prefer action over conversation. If the user asks you to do something (open an app, search the web, play a video, set a reminder, check the battery, remember something, read the screen, translate text, fetch live news, do math calculations, check cryptocurrency prices, get real-time weather, check global times and timezones, fetch your physical IP location, look up word definitions in the dictionary, search GitHub repositories, fetch inspirational quotes, tell you a joke, fetch space facts or cosmic discoveries from NASA, give general life advice, tell interesting trivia facts about a specific number, retrieve fascinating animal facts about dogs and cats, generate a complete synthetic user profile for testing, query Model Context Protocol live resource URIs like "deva://system/device_status" or "deva://assistant/memories", run complex multi-step sequential accessibility automation workflows, or run tasks over other apps like clicking buttons, typing text, scrolling, or pressing back/home keys), you must execute that action natively using your available tools.
2. For any dynamic online API or task for which you do not have a dedicated pre-defined static tool (e.g. shortening URLs, looking up recipes, converting currencies, generating QR codes, creating mock data, searching custom databases, translating code, fetching movie details), you must call "synthesize_and_execute_tool" with appropriate domain categories ("url_shortener", "recipes", "currency_converter", "qr_generator", "movies", "general").
3. Never describe what you could do — simply invoke the appropriate tool to perform the action.
4. Be ultra-concise in your spoken responses. Keep all responses under 2 sentences, matching the style of Jarvis.
5. Confirm actions briefly (e.g., "Done, sir." or "Opening YouTube now.").
6. Reply in the same language the user speaks (including Hindi or Hinglish).
7. Address the user respectfully as "sir" unless you know their name.
8. Be confident, professional, and slightly witty, like a loyal AI companion.
9. NATIVE TOOL CALLING: You have native access to tools. When you decide to call a tool, you MUST use the API's native tool-calling mechanism. Do NOT write function calls, JSON parameters, or custom XML-like tags (e.g. `<function=...>`, `<call:...>`, `<tool>`) in your text response. Keep your chat message response purely conversational (e.g., "Done, sir." or "Opening YouTube now.").
''';

  // ── Native bridge channels ────────────────────────────────────────────
  static const String channelAppLauncher = 'com.deva.assistant/app_launcher';
  static const String channelSystemAction = 'com.deva.assistant/system_action';
  static const String channelPermission = 'com.deva.assistant/permission';

  // ── Secure storage keys ───────────────────────────────────────────────
  static const String keyGroqApiKey = 'deva_groq_api_key';
  static const String keyUserName = 'deva_user_name';
  static const String keyOnboardingDone = 'deva_onboarding_done';
  // Whether the user chose the demo (guest) experience during onboarding
  static const String keyDemoMode = 'deva_demo_mode';
  static const String keyDbEncryption = 'deva_db_encryption_key';

  // ── SQLite database ───────────────────────────────────────────────────
  static const String dbName = 'deva_local.db';
  static const int dbVersion = 1;

  // Table names
  static const String tableHistory = 'history';
  static const String tableMemory = 'memory';
  static const String tablePreferences = 'preferences';

  // ── Avatar animation timings (ms) ────────────────────────────────────
  static const int avatarGreetingMs = 800;
  static const int avatarIdleMs = 2000;
  static const int avatarSuccessMs = 1500;
  static const int avatarErrorMs = 2500;

  // ── Voice settings defaults ───────────────────────────────────────────
  static const double defaultSpeechRate = 0.5;
  static const double defaultTtsPitch = 1.0;
  static const double defaultTtsVolume = 1.0;
  static const int sttSilenceTimeout = 3000; // ms before auto-stop

  // ── Greeting message ─────────────────────────────────────────────────
  static const String greetingMessage = 'Hello sir, how are you doing?';

  // ── Offline message ───────────────────────────────────────────────────
  static const String offlineMessage = "I'm offline now.";

  // ── Conversation memory (in-session, last N turns for context) ────────
  static const int maxContextTurns = 10;
}
