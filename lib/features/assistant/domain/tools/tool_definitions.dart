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
    description:
        'Opens an installed app on the user\'s Android device. Use this whenever the user says "open", "launch", "start", "go to", or mentions an app name like YouTube, WhatsApp, Instagram, Camera, Settings, Chrome, Maps, etc.',
    parameters: {
      'type': 'object',
      'properties': {
        'app_name': {
          'type': 'string',
          'description':
              'The common name of the app (e.g., YouTube, WhatsApp, Instagram, Camera, Chrome, Settings, Maps, Calculator, Clock, Calendar, Gmail, Phone, Messages, Spotify, Netflix)',
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

  // ── Tool: Install an app ──────────────────────────────────────────────
  static const installApp = ToolDefinition(
    name: 'install_app',
    description:
        'Opens the Google Play Store to install an app. Use this when the user asks to "install", "download", or "get" an app (e.g. "Install WhatsApp", "Download Netflix").',
    parameters: {
      'type': 'object',
      'properties': {
        'app_name': {
          'type': 'string',
          'description': 'The name of the app to install (e.g. "WhatsApp", "Instagram")',
        },
      },
      'required': ['app_name'],
    },
  );

  // ── Tool: Web search ──────────────────────────────────────────────────
  static const webSearch = ToolDefinition(
    name: 'web_search',
    description:
        'Opens the browser and searches the web for a query. Use this when the user asks a factual question you cannot answer, says "search for", "look up", "find", "Google", or asks about news, weather, prices, scores, or anything requiring real-time information.',
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
    description:
        'Searches and plays a video or music on YouTube. Use this when the user says "play", "put on", "listen to", or asks for a song, music, video, movie trailer, podcast, or any media content.',
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
    description:
        'Sets an alarm or reminder on the user\'s device. Use this when the user says "remind me", "set alarm", "wake me up", "set timer", or mentions any time-based task.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'What the reminder is for',
        },
        'time': {
          'type': 'string',
          'description':
              'Time as ISO 8601 string or natural language (e.g., "8:00 AM tomorrow")',
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
    description:
        'Stores a piece of information locally that the user wants DEVA to remember. Data is stored only on-device.',
    parameters: {
      'type': 'object',
      'properties': {
        'key': {
          'type': 'string',
          'description':
              'The label for what to remember (e.g., "favorite_color")',
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
    description:
        'Checks the current battery level and charging status of the device.',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Read Screen ───────────────────────────────────────────────────
  static const readScreen = ToolDefinition(
    name: 'read_screen',
    description:
        'Reads all the text currently visible on the user\'s screen. Use this when the user asks you to "summarize this", "read this", or asks questions about what they are looking at.',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Make HTTP Request ──────────────────────────────────────
  static const makeHttpRequest = ToolDefinition(
    name: 'make_http_request',
    description:
        'Makes an HTTP request to control local smart home devices (like Philips Hue or Home Assistant) or fetch data. Use this when the user asks to turn on lights, change temperature, or trigger a webhook.',
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

  // ── Tool: Get Weather ───────────────────────────────────────────────────
  static const getWeather = ToolDefinition(
    name: 'get_weather',
    description:
        'Fetches real-time weather information (temperature, wind, condition) for a city or coordinates using open-meteo (completely free, no API key required). Use this when the user asks about the weather.',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {
          'type': 'string',
          'description':
              'The name of the city (e.g., "Mumbai", "London", "New York")',
        },
        'latitude': {
          'type': 'number',
          'description': 'Latitude coordinates (optional)',
        },
        'longitude': {
          'type': 'number',
          'description': 'Longitude coordinates (optional)',
        },
      },
      'required': ['city'],
    },
  );

  // ── Tool: Wikipedia Search ──────────────────────────────────────────────
  static const wikipediaSearch = ToolDefinition(
    name: 'wikipedia_search',
    description:
        'Searches Wikipedia for an encyclopedia article summary (completely free, no API key required). Use this when the user asks factual questions like "Who was...", "What is...", "Explain the concept of..." to get direct answers in the background.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The topic or concept to search for on Wikipedia',
        },
      },
      'required': ['query'],
    },
  );

  // ── Tool: Get Crypto Price ──────────────────────────────────────────────
  static const getCryptoPrice = ToolDefinition(
    name: 'get_crypto_price',
    description:
        'Fetches the current real-time price of any cryptocurrency (like Bitcoin, Ethereum, Dogecoin) using CoinGecko (completely free, no API key required). Use this when the user asks about crypto prices.',
    parameters: {
      'type': 'object',
      'properties': {
        'coin': {
          'type': 'string',
          'description':
              'The common name of the coin (e.g., "bitcoin", "ethereum", "dogecoin", "solana")',
        },
      },
      'required': ['coin'],
    },
  );

  // ── Tool: Translate Text ────────────────────────────────────────────────
  static const translateText = ToolDefinition(
    name: 'translate_text',
    description:
        'Translates any text from one language to another using Google Translate (completely free, no API key required). Use this when the user asks to "translate", "how do you say", or wants something translated.',
    parameters: {
      'type': 'object',
      'properties': {
        'text': {
          'type': 'string',
          'description': 'The text to translate',
        },
        'target_language': {
          'type': 'string',
          'description':
              'The language to translate into (e.g., "Spanish", "French", "Hindi", "German", "Japanese")',
        },
      },
      'required': ['text', 'target_language'],
    },
  );

  // ── Tool: Get News ──────────────────────────────────────────────────────
  static const getNews = ToolDefinition(
    name: 'get_news',
    description:
        'Fetches the top global news headlines from Google News RSS (completely free, no API key required). Use this when the user asks for "news", "headlines", "what is happening in the world".',
    parameters: {
      'type': 'object',
      'properties': {
        'category': {
          'type': 'string',
          'enum': [
            'technology',
            'business',
            'science',
            'sports',
            'entertainment',
            'general'
          ],
          'description': 'Optional news category',
        },
      },
      'required': [],
    },
  );

  // ── Tool: Get System Info ───────────────────────────────────────────────
  static const getSystemInfo = ToolDefinition(
    name: 'get_system_info',
    description:
        'Checks local device system diagnostics (operating system, CPU/platform, storage space, network status, local IP). Use this when the user asks about device storage, specs, diagnostics, or says "system details".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Calculate Math ────────────────────────────────────────────────
  static const calculateMath = ToolDefinition(
    name: 'calculate_math',
    description:
        'Evaluates a mathematical equation or expression locally. Use this when the user asks to perform calculations, multiplication, addition, division, square roots, etc. (e.g., "What is 245 * 12?").',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {
          'type': 'string',
          'description':
              'The mathematical expression to evaluate (e.g., "245 * 12 + 15")',
        },
      },
      'required': ['expression'],
    },
  );

  // ── Tool: Get Timezone Time ─────────────────────────────────────────────
  static const getTimezoneTime = ToolDefinition(
    name: 'get_timezone_time',
    description:
        'Fetches the current local time in any city or timezone in the world (completely free, no API key required). Use this when the user asks "what time is it in [city]".',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {
          'type': 'string',
          'description':
              'The name of the city (e.g., "Tokyo", "London", "New York")',
        },
      },
      'required': ['city'],
    },
  );

  // ── Tool: Get My Location ───────────────────────────────────────────────
  static const getMyLocation = ToolDefinition(
    name: 'get_my_location',
    description:
        'Fetches the user\'s physical location details (city, region, country, ZIP, ISP) based on their network IP address (completely free, no API key required). Use this when the user asks "where am I?", "what is my location?", or "check my IP".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Define Word ───────────────────────────────────────────────────
  static const defineWord = ToolDefinition(
    name: 'define_word',
    description:
        'Looks up the exact definition, synonyms, and pronunciation of any English word (completely free, no API key required). Use this when the user asks "what is the meaning of [word]?", "define [word]", or "what does [word] mean?".',
    parameters: {
      'type': 'object',
      'properties': {
        'word': {
          'type': 'string',
          'description': 'The English word to define',
        },
      },
      'required': ['word'],
    },
  );

  // ── Tool: GitHub Search ─────────────────────────────────────────────────
  static const githubSearchRepos = ToolDefinition(
    name: 'github_search_repos',
    description:
        'Searches GitHub for the top public repositories matching a keyword (completely free, no API key required). Returns their names, star counts, and descriptions. Use this when the user asks to find code repositories, GitHub projects, or open-source libraries.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'The repository search topic (e.g., "flutter navigation", "neural network python")',
        },
      },
      'required': ['query'],
    },
  );

  // ── Tool: Get Random Quote ──────────────────────────────────────────────
  static const getRandomQuote = ToolDefinition(
    name: 'get_random_quote',
    description:
        'Fetches an inspiring, philosophical, or motivational quote (completely free, no API key required). Use this when the user asks for a quote, motivation, inspiration, or says "inspire me".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Get Random Joke ───────────────────────────────────────────────
  static const getRandomJoke = ToolDefinition(
    name: 'get_random_joke',
    description:
        'Fetches a clean, funny joke (completely free, no API key required). Use this when the user asks to hear a joke, laugh, or says "make me laugh".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Get Space Fact ────────────────────────────────────────────────
  static const getSpaceFactOrImage = ToolDefinition(
    name: 'get_space_fact_or_image',
    description:
        'Fetches today\'s official NASA Astronomy Picture of the Day discovery fact and title (completely free, no API key required). Use this when the user asks about space facts, NASA, astronomy, or "what happened in space today?".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Get Advice ────────────────────────────────────────────────────
  static const getRandomAdvice = ToolDefinition(
    name: 'get_random_advice',
    description:
        'Fetches a practical life hack, general advice, or wisdom tip (completely free, no API key required). Use this when the user asks for advice, a tip, life hacks, or says "give me some advice".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Get Number Fact ────────────────────────────────────────────────
  static const getNumberFact = ToolDefinition(
    name: 'get_number_fact',
    description:
        'Fetches an interesting trivia or mathematical fact about a number (completely free, no API key required). Use this when the user asks about trivia for a number, or says "tell me a fact about the number [number]".',
    parameters: {
      'type': 'object',
      'properties': {
        'number': {
          'type': 'string',
          'description': 'The number to look up (e.g., "42", "100", "7")',
        },
      },
      'required': ['number'],
    },
  );

  // ── Tool: Get Animal Fact ────────────────────────────────────────────────
  static const getAnimalFact = ToolDefinition(
    name: 'get_animal_fact',
    description:
        'Fetches a fascinating trivia fact about dogs, cats, or the animal kingdom (completely free, no API key required). Use this when the user asks for animal facts, dog trivia, or cat trivia.',
    parameters: {
      'type': 'object',
      'properties': {
        'animal': {
          'type': 'string',
          'enum': ['dog', 'cat', 'general'],
          'description': 'The type of animal (defaults to "general")',
        },
      },
      'required': [],
    },
  );

  // ── Tool: Generate Identity ─────────────────────────────────────────────
  static const generateTestIdentity = ToolDefinition(
    name: 'generate_test_identity',
    description:
        'Generates a complete mock synthetic profile (fake name, email, address, country, birth date) for testing or developer purposes (completely free, no API key required). Use this when the user asks to "generate a test profile", "make a fake identity", or "create mock user details".',
    parameters: {
      'type': 'object',
      'properties': {},
      'required': [],
    },
  );

  // ── Tool: Perform Accessibility Action ──────────────────────────────────
  static const performAccessibilityAction = ToolDefinition(
    name: 'perform_accessibility_action',
    description:
        'Natively performs clicks, text typing, scrolls, or presses back/home on any third-party app visible on the screen. Always use this when the user requests tasks like "click search", "type message", "scroll down", "go back", or "go home".',
    parameters: {
      'type': 'object',
      'properties': {
        'action': {
          'type': 'string',
          'enum': [
            'click',
            'type',
            'scroll_down',
            'scroll_up',
            'go_back',
            'go_home'
          ],
          'description': 'The accessibility gesture/action type to execute',
        },
        'target': {
          'type': 'string',
          'description':
              'The text or label of the button, input field, or element to target (required for click and type)',
        },
        'text': {
          'type': 'string',
          'description':
              'The exact text message to enter or type into the focused target input field (required for type)',
        },
      },
      'required': ['action'],
    },
  );

  // ── Tool: Read MCP Resource ─────────────────────────────────────────────
  static const readMcpResource = ToolDefinition(
    name: 'read_mcp_resource',
    description:
        'Queries the official Model Context Protocol (MCP) Resource schema to read-only system and assistant contexts. Use this when you need detailed status context on the assistant or device. Supported URIs: "deva://system/device_status" (battery, screen status, time/date, networks) and "deva://assistant/memories" (saved facts/preferences).',
    parameters: {
      'type': 'object',
      'properties': {
        'uri': {
          'type': 'string',
          'description':
              'The MCP Resource URI schema to read (e.g., "deva://system/device_status" or "deva://assistant/memories")',
        },
      },
      'required': ['uri'],
    },
  );

  // ── Tool: Execute MCP Workflow ──────────────────────────────────────────
  static const executeMcpWorkflow = ToolDefinition(
    name: 'execute_mcp_workflow',
    description:
        'Executes a sequential multi-step macro workflow chain of native Android actions in a single turn. Excellent for complex multi-app tasks. Steps can include: "open_app" (requires appName), "click" (requires target), "type" (requires target and text), "scroll_down", "scroll_up", "go_back", or "go_home". Example steps parameter: [{"action": "open_app", "appName": "WhatsApp"}, {"action": "click", "target": "Search"}, {"action": "type", "target": "Search", "text": "Dad"}]',
    parameters: {
      'type': 'object',
      'properties': {
        'steps': {
          'type': 'array',
          'description':
              'The ordered list of action steps to execute sequentially',
          'items': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': [
                  'open_app',
                  'click',
                  'type',
                  'scroll_down',
                  'scroll_up',
                  'go_back',
                  'go_home'
                ],
                'description': 'The action type to perform',
              },
              'appName': {
                'type': 'string',
                'description':
                    'The app package name or visual label to open (required for open_app action)',
              },
              'target': {
                'type': 'string',
                'description':
                    'The text label of the button or element to target (required for click and type)',
              },
              'text': {
                'type': 'string',
                'description':
                    'The text message string to write/type into the targeted field (required for type)',
              },
            },
            'required': ['action'],
          },
        },
      },
      'required': ['steps'],
    },
  );

  // ── Tool: Synthesize and Execute Infinite AI Tool ──────────────────────
  static const synthesizeAndExecuteTool = ToolDefinition(
    name: 'synthesize_and_execute_tool',
    description:
        'Dynamic Infinite AI tool and API routing agent. Use this when the user asks you to perform a task for which you do not have a dedicated pre-defined static tool (e.g. shortening URLs, looking up recipes, converting currencies, generating QR codes, creating mock data, searching custom databases, translating code, fetching movie details). Fully resolves free public APIs in real-time.',
    parameters: {
      'type': 'object',
      'properties': {
        'task': {
          'type': 'string',
          'description':
              'The detailed user request or goal to achieve (e.g., "Shorten URL https://google.com" or "Suggest a recipe for pasta")',
        },
        'domain': {
          'type': 'string',
          'description':
              'The category or domain of the tool/API required (e.g., "url_shortener", "recipes", "currency_converter", "qr_generator", "movies", "general")',
        },
      },
      'required': ['task', 'domain'],
    },
  );

  // ── Tool: Modify Self ───────────────────────────────────────────────────
  static const modifySelf = ToolDefinition(
    name: 'modify_self',
    description:
        'Enables DEVA to self-modify, rewrite its core operational rules, update system parameters, register new custom macro workflows, or update its local database preferences. Use this when the user says "modify yourself", "rewrite your rules", "register a new skill", "update your persona", or "change your system behavior".',
    parameters: {
      'type': 'object',
      'properties': {
        'modification_type': {
          'type': 'string',
          'enum': [
            'persona_update',
            'macro_registration',
            'preference_override'
          ],
          'description': 'The type of self-modification to execute',
        },
        'key': {
          'type': 'string',
          'description':
              'The configuration key, macro trigger phrase, or system prompt variable to rewrite',
        },
        'value': {
          'type': 'string',
          'description':
              'The new content, macro workflow script (JSON array string), or persona description to write',
        },
      },
      'required': ['modification_type', 'key', 'value'],
    },
  );

  /// All tools as a JSON-serialisable list — passed to Groq API.
  static List<Map<String, dynamic>> get allAsJson => [
        openApp.toJson(),
        installApp.toJson(),
        webSearch.toJson(),
        playOnYoutube.toJson(),
        setReminder.toJson(),
        remember.toJson(),
        openUrl.toJson(),
        getBatteryLevel.toJson(),
        readScreen.toJson(),
        makeHttpRequest.toJson(),
        getWeather.toJson(),
        wikipediaSearch.toJson(),
        getCryptoPrice.toJson(),
        translateText.toJson(),
        getNews.toJson(),
        getSystemInfo.toJson(),
        calculateMath.toJson(),
        getTimezoneTime.toJson(),
        getMyLocation.toJson(),
        defineWord.toJson(),
        githubSearchRepos.toJson(),
        getRandomQuote.toJson(),
        getRandomJoke.toJson(),
        getSpaceFactOrImage.toJson(),
        getRandomAdvice.toJson(),
        getNumberFact.toJson(),
        getAnimalFact.toJson(),
        generateTestIdentity.toJson(),
        performAccessibilityAction.toJson(),
        readMcpResource.toJson(),
        executeMcpWorkflow.toJson(),
        synthesizeAndExecuteTool.toJson(),
        modifySelf.toJson(),
      ];

  /// All tool names.
  static const allNames = {
    'open_app',
    'install_app',
    'web_search',
    'play_on_youtube',
    'set_reminder',
    'remember',
    'open_url',
    'get_battery_level',
    'read_screen',
    'make_http_request',
    'get_weather',
    'wikipedia_search',
    'get_crypto_price',
    'translate_text',
    'get_news',
    'get_system_info',
    'calculate_math',
    'get_timezone_time',
    'get_my_location',
    'define_word',
    'github_search_repos',
    'get_random_quote',
    'get_random_joke',
    'get_space_fact_or_image',
    'get_random_advice',
    'get_number_fact',
    'get_animal_fact',
    'generate_test_identity',
    'perform_accessibility_action',
    'read_mcp_resource',
    'execute_mcp_workflow',
    'synthesize_and_execute_tool',
    'modify_self'
  };
}
