/// App-wide constants for DEVA.
library;

class AppConstants {
  AppConstants._();

  // ── App identity ──────────────────────────────────────────────────────
  static const String appName       = 'DEVA';
  static const String appVersion    = '1.0.0';
  static const String appTagline    = 'Your personal AI assistant';

  // ── AI API Routing ──────────────────────────────────────────────────────
  // If you deploy the Stateless Proxy (proxy/worker.js), place the URL here.
  // Otherwise, leave empty to use direct Groq connection (less secure).
  static const String proxyBaseUrl  = ' https://deva-proxy.deva-proxy-devan-20260516.workers.dev'; // e.g. 'https://deva-proxy.your-name.workers.dev'
  static const String groqBaseUrl   = 'https://api.groq.com/openai/v1';
  static const String groqModel     = 'llama-3.3-70b-versatile';
  static const int    groqMaxTokens = 512;   // Keep responses concise for TTS
  static const double groqTemp      = 0.7;

  // ── DEVA system prompt ────────────────────────────────────────────────
  static const String systemPrompt = '''
You are DEVA, a premium voice-first AI assistant. 
Respond concisely and naturally since your responses will be spoken aloud.
Always reply in the exact language the user is speaking.
Keep responses under 3 sentences unless more detail is explicitly needed.
Use tools when the user requests an action (open app, search, reminder, etc.).
Be friendly, professional, and futuristic in tone.
All user data stays on their device. You do NOT store or transmit any personal information.
''';

  // ── Native bridge channels ────────────────────────────────────────────
  static const String channelAppLauncher  = 'com.deva.assistant/app_launcher';
  static const String channelSystemAction = 'com.deva.assistant/system_action';
  static const String channelPermission   = 'com.deva.assistant/permission';

  // ── Secure storage keys ───────────────────────────────────────────────
  static const String keyGroqApiKey       = 'deva_groq_api_key';
  static const String keyUserName         = 'deva_user_name';
  static const String keyOnboardingDone   = 'deva_onboarding_done';
  static const String keyDbEncryption     = 'deva_db_encryption_key';

  // ── SQLite database ───────────────────────────────────────────────────
  static const String dbName            = 'deva_local.db';
  static const int    dbVersion         = 1;

  // Table names
  static const String tableHistory      = 'history';
  static const String tableMemory       = 'memory';
  static const String tablePreferences  = 'preferences';

  // ── Avatar animation timings (ms) ────────────────────────────────────
  static const int avatarGreetingMs   = 800;
  static const int avatarIdleMs       = 2000;
  static const int avatarSuccessMs    = 1500;
  static const int avatarErrorMs      = 2500;

  // ── Voice settings defaults ───────────────────────────────────────────
  static const double defaultSpeechRate  = 0.5;
  static const double defaultTtsPitch    = 1.0;
  static const double defaultTtsVolume   = 1.0;
  static const int    sttSilenceTimeout  = 3000; // ms before auto-stop

  // ── Greeting message ─────────────────────────────────────────────────
  static const String greetingMessage = 'Hello sir, how are you doing?';

  // ── Offline message ───────────────────────────────────────────────────
  static const String offlineMessage  = "I'm offline now.";

  // ── Conversation memory (in-session, last N turns for context) ────────
  static const int maxContextTurns = 10;
}
