/// Tool definitions for Groq function calling (OpenAI-compatible format).
/// These define what actions DEVA can take on the user's device.
library;

/// A single Groq/OpenAI-format tool definition.
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// All tools available to DEVA.
class DevaTools {
  DevaTools._();

  // ── Tool: Open an app ─────────────────────────────────────────────────
  static const openApp = ToolDefinition(
    name: 'open_app',
    description: 'Opens an installed app on the user\'s Android device.',
    parameters: {
      'type': 'object',
      'properties': {
        'app_name': {
          'type': 'string',
          'description': 'The common name of the app (e.g., YouTube, WhatsApp)',
        },
        'package_name': {
          'type': 'string',
          'description':
              'Android package name if known (e.g., com.google.android.youtube)',
        },
      },
      'required': ['app_name'],
    },
  );

  // ── Tool: Web search ──────────────────────────────────────────────────
  static const webSearch = ToolDefinition(
    name: 'web_search',
    description: 'Opens the browser and searches the web for the given query.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The search query',
        },
      },
      'required': ['query'],
    },
  );

  // ── Tool: Play on YouTube ─────────────────────────────────────────────
  static const playOnYoutube = ToolDefinition(
    name: 'play_on_youtube',
    description: 'Searches and plays a video on YouTube.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'What to search for and play on YouTube',
        },
      },
      'required': ['query'],
    },
  );

  // ── Tool: Set reminder / alarm ────────────────────────────────────────
  static const setReminder = ToolDefinition(
    name: 'set_reminder',
    description: 'Sets an alarm or reminder on the user\'s device.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'What the reminder is for',
        },
        'time': {
          'type': 'string',
          'description': 'Time as ISO 8601 string or natural language (e.g., "8:00 AM tomorrow")',
        },
        'recurring': {
          'type': 'boolean',
          'description': 'Whether the alarm should repeat daily',
        },
      },
      'required': ['title', 'time'],
    },
  );

  // ── Tool: Remember something ──────────────────────────────────────────
  static const remember = ToolDefinition(
    name: 'remember',
    description: 'Stores a piece of information locally that the user wants DEVA to remember. Data is stored only on-device.',
    parameters: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description': 'The label for what to remember (e.g., "favorite_color")',
        },
        'value': {
          'type': 'string',
          'description': 'The value to remember',
        },
        'category': {
          'type': 'string',
          'enum': ['preference', 'fact', 'task', 'contact'],
          'description': 'Type of memory',
        },
      },
      'required': ['key', 'value'],
    },
  );

  // ── Tool: Open URL ────────────────────────────────────────────────────
  static const openUrl = ToolDefinition(
    name: 'open_url',
    description: 'Opens a specific URL in the browser.',
    parameters: {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'The full URL to open (must start with https://)',
        },
      },
      'required': ['url'],
    },
  );

  // ── Tool: System Status (Battery) ───────────────────────────────────────
  static const getBatteryLevel = ToolDefinition(
    name: 'get_battery_level',
    description: 'Checks the current battery level and charging status of the device.',
    parameters: {
      'type': 'object',
      'properties': {},
    },
  );

  // ── Tool: Read Screen ───────────────────────────────────────────────────
  static const readScreen = ToolDefinition(
    name: 'read_screen',
    description: 'Reads all the text currently visible on the user\'s screen. Use this when the user asks you to "summarize this", "read this", or asks questions about what they are looking at.',
    parameters: {
      'type': 'object',
      'properties': {},
    },
  );

  // ── Tool: Smart Home / HTTP Request ──────────────────────────────────────
  static const makeHttpRequest = ToolDefinition(
    name: 'make_http_request',
    description: 'Makes an HTTP request to control local smart home devices (like Philips Hue or Home Assistant) or fetch data. Use this when the user asks to turn on lights, change temperature, or trigger a webhook.',
    parameters: {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description': 'The URL or IP address to send the request to',
        },
        'method': {
          'type': 'string',
          'enum': ['GET', 'POST', 'PUT', 'DELETE'],
        },
        'body': {
          'type': 'string',
          'description': 'Optional JSON body payload as a string',
        },
      },
      'required': ['url', 'method'],
    },
  );

  /// All tools as a JSON-serialisable list — passed to Groq API.
  static List<Map<String, dynamic>> get allAsJson => [
    openApp.toJson(),
    webSearch.toJson(),
    playOnYoutube.toJson(),
    setReminder.toJson(),
    remember.toJson(),
    openUrl.toJson(),
    getBatteryLevel.toJson(),
    readScreen.toJson(),
    makeHttpRequest.toJson(),
  ];

  /// All tool names.
  static const allNames = {
    'open_app', 'web_search', 'play_on_youtube', 'set_reminder', 'remember', 'open_url', 'get_battery_level', 'read_screen', 'make_http_request'
  };
}
