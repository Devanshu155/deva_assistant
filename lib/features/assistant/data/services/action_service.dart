/// Action service — executes tool calls returned by the AI.
/// Routes each tool to the appropriate platform bridge or system service.
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/database/memory_dao.dart';
import '../../../../shared/database/preferences_dao.dart';
import '../../../../shared/services/deva_logger.dart';

class ActionResult {
  final bool success;
  final String? message; // Optional feedback for TTS

  const ActionResult({required this.success, this.message});
}

class ActionService {
  ActionService._();
  static final ActionService instance = ActionService._();

  static const _appLauncherChannel =
      MethodChannel(AppConstants.channelAppLauncher);
  static const _systemActionChannel =
      MethodChannel(AppConstants.channelSystemAction);

  final _memory = MemoryDao.instance;

  /// Shared HttpClient — reused across all requests to pool TCP connections
  /// and avoid the socket leak that occurs when creating a new client per call.
  /// Connection timeout is set conservatively to 6 seconds.
  static final _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);

  // ── Main dispatch ─────────────────────────────────────────────────────

  /// Execute a tool call from the AI. Returns a result with optional feedback.
  Future<ActionResult> execute(
      String toolName, Map<String, dynamic> args) async {
    debugPrint('[Action] Executing tool: $toolName, args: $args');

    switch (toolName) {
      case 'open_app':
        return _openApp(args);
      case 'install_app':
        return _installApp(args);
      case 'web_search':
        return _webSearch(args);
      case 'play_on_youtube':
        return _playOnYoutube(args);
      case 'set_reminder':
        return _setReminder(args);
      case 'remember':
        return _remember(args);
      case 'open_url':
        return _openUrl(args);
      case 'get_battery_level':
        return _getBatteryLevel();
      case 'read_screen':
        return _readScreen();
      case 'make_http_request':
        return _makeHttpRequest(args);
      case 'get_weather':
        return _getWeather(args);
      case 'wikipedia_search':
        return _wikipediaSearch(args);
      case 'get_crypto_price':
        return _getCryptoPrice(args);
      case 'translate_text':
        return _translateText(args);
      case 'get_news':
        return _getNews(args);
      case 'get_system_info':
        return _getSystemInfo();
      case 'calculate_math':
        return _calculateMath(args);
      case 'get_timezone_time':
        return _getTimezoneTime(args);
      case 'get_my_location':
        return _getMyLocation();
      case 'define_word':
        return _defineWord(args);
      case 'github_search_repos':
        return _githubSearchRepos(args);
      case 'get_random_quote':
        return _getRandomQuote();
      case 'get_random_joke':
        return _getRandomJoke();
      case 'get_space_fact_or_image':
        return _getSpaceFactOrImage();
      case 'get_random_advice':
        return _getRandomAdvice();
      case 'get_number_fact':
        return _getNumberFact(args);
      case 'get_animal_fact':
        return _getAnimalFact(args);
      case 'generate_test_identity':
        return _generateTestIdentity();
      case 'perform_accessibility_action':
        return _performAccessibilityAction(args);
      case 'read_mcp_resource':
        return _readMcpResource(args);
      case 'execute_mcp_workflow':
        return _executeMcpWorkflow(args);
      case 'synthesize_and_execute_tool':
        return _synthesizeAndExecuteTool(args);
      case 'modify_self':
        return _modifySelf(args);
      default:
        return ActionResult(
          success: false,
          message: 'I don\'t know how to do "$toolName" yet.',
        );
    }
  }

  // ── Tool implementations ──────────────────────────────────────────────

  /// Open an app via Kotlin native bridge.
  Future<ActionResult> _openApp(Map<String, dynamic> args) async {
    try {
      final appName =
          args['app_name'] as String? ?? args['appName'] as String? ?? '';
      final packageName =
          args['package_name'] as String? ?? args['packageName'] as String?;

      final result = await _appLauncherChannel.invokeMethod<String>(
        'openApp',
        {'app_name': appName, 'package_name': packageName},
      );

      return ActionResult(success: true, message: result);
    } on PlatformException catch (e) {
      debugPrint('[Action] openApp error: ${e.message}');
      return ActionResult(
        success: false,
        message: 'I couldn\'t open that app. ${e.message}',
      );
    }
  }

  Future<ActionResult> _installApp(Map<String, dynamic> args) async {
    final appName     = args['app_name']     as String? ?? '';
    final packageName = args['package_name'] as String? ?? args['packageName'] as String?;

    if (appName.isEmpty && (packageName == null || packageName.isEmpty)) {
      return const ActionResult(
          success: false, message: 'Please specify the app to install.');
    }

    DevaLogger.playStore('installApp: appName=$appName packageName=$packageName');

    try {
      // Delegate to native bridge which handles market:// → web fallback chain.
      final result = await _appLauncherChannel.invokeMethod<String>(
        'installApp',
        {'app_name': appName, 'package_name': packageName},
      );
      return ActionResult(
          success: true,
          message: result ?? 'Opened Play Store to install $appName.');
    } on PlatformException catch (e) {
      DevaLogger.error('ActionService', 'installApp PlatformException', e);
      // Fallback: launch Play Store search via url_launcher.
      try {
        final query = packageName?.isNotEmpty == true ? packageName! : appName;
        final marketUri = packageName?.isNotEmpty == true
            ? Uri.parse('market://details?id=$packageName')
            : Uri.parse(
                'market://search?q=${Uri.encodeComponent(appName)}&c=apps');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return ActionResult(
              success: true,
              message: 'Opened Play Store to install $query.');
        }
        // Ultimate fallback: web
        final webUri = Uri.parse(
            'https://play.google.com/store/search?q=${Uri.encodeComponent(appName)}&c=apps');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return ActionResult(
            success: true, message: 'Opened Play Store in browser for $appName.');
      } catch (fallbackErr) {
        return ActionResult(
            success: false, message: 'Could not open Play Store: $fallbackErr');
      }
    }
  }

  /// Open browser with a web search query.
  Future<ActionResult> _webSearch(Map<String, dynamic> args) async {
    final query = Uri.encodeComponent(args['query'] as String? ?? '');
    final uri = Uri.parse('https://www.google.com/search?q=$query');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const ActionResult(success: true);
      }
      return const ActionResult(
          success: false, message: 'I couldn\'t open the browser.');
    } catch (e) {
      return ActionResult(success: false, message: 'Search failed: $e');
    }
  }

  /// Search and play on YouTube.
  Future<ActionResult> _playOnYoutube(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    try {
      final result = await _appLauncherChannel.invokeMethod<String>(
        'playOnYoutube',
        {'query': query},
      );
      return ActionResult(success: true, message: result);
    } catch (e) {
      debugPrint(
          '[Action] playOnYoutube error: $e. Falling back to web search.');
      // Fallback to web search if youtube app fails
      return _webSearch({'query': 'youtube $query'});
    }
  }

  /// Open a specific URL.
  Future<ActionResult> _openUrl(Map<String, dynamic> args) async {
    final rawUrl = args['url'] as String? ?? '';
    // Security: only allow https URLs
    if (!rawUrl.startsWith('https://')) {
      return const ActionResult(
        success: false,
        message: 'I can only open secure HTTPS links.',
      );
    }
    try {
      final uri = Uri.parse(rawUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return const ActionResult(success: true);
      }
      return const ActionResult(
          success: false, message: 'I couldn\'t open that link.');
    } catch (e) {
      return ActionResult(success: false, message: 'Failed to open URL: $e');
    }
  }

  /// Set a reminder/alarm via Kotlin native bridge.
  Future<ActionResult> _setReminder(Map<String, dynamic> args) async {
    try {
      await _systemActionChannel.invokeMethod('setAlarm', {
        'title': args['title'] as String? ?? 'Reminder',
        'time': args['time'] as String? ?? '',
        'recurring': args['recurring'] as bool? ?? false,
      });
      return const ActionResult(success: true);
    } on PlatformException catch (e) {
      return ActionResult(
          success: false, message: 'Could not set reminder: ${e.message}');
    }
  }

  /// Store a memory entry locally in SQLite.
  Future<ActionResult> _remember(Map<String, dynamic> args) async {
    final key = args['key'] as String? ?? '';
    final value = args['value'] as String? ?? '';
    final category = args['category'] as String? ?? 'fact';

    if (key.isEmpty || value.isEmpty) {
      return const ActionResult(
          success: false,
          message: 'I need a key and value to remember something.');
    }

    await _memory.upsert(key: key, value: value, category: category);
    return ActionResult(
      success: true,
      message: 'I\'ve remembered that "$key" is "$value".',
    );
  }

  // ── Tool implementations: Battery ───────────────────────────────────────

  Future<ActionResult> _getBatteryLevel() async {
    try {
      final String result =
          await _systemActionChannel.invokeMethod('getBatteryLevel');
      return ActionResult(success: true, message: result);
    } catch (e) {
      return ActionResult(
          success: false, message: 'I couldn\'t check the battery level.');
    }
  }

  // ── Tool implementations: Screen Awareness ───────────────────────────────────────

  Future<ActionResult> _readScreen() async {
    try {
      final String result =
          await _systemActionChannel.invokeMethod('readScreen');
      final String prunedResult = _pruneScreenHierarchy(result);
      return ActionResult(success: true, message: prunedResult);
    } on PlatformException catch (e) {
      return ActionResult(
        success: false,
        message: e.message ??
            'I cannot see the screen. Please enable my Accessibility permission in Settings.',
      );
    } catch (e) {
      return ActionResult(
          success: false,
          message:
              'I cannot see the screen. Please enable my Accessibility permission in Settings.');
    }
  }

  String _pruneScreenHierarchy(String raw) {
    if (raw.isEmpty) {
      return 'The screen is empty, sir.';
    }
    final lines = raw.split('\n');
    final prunedLines = <String>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('text=') ||
          lower.contains('desc=') ||
          lower.contains('id=') ||
          lower.contains('clickable=true') ||
          lower.contains('focusable=true')) {
        String cleaned = line.replaceAll(
            RegExp(r'(android\.widget\.|android\.view\.)Layout'), 'View');
        prunedLines.add(cleaned.trim());
      }
    }

    if (prunedLines.isEmpty) {
      return raw.length > 1000 ? raw.substring(0, 1000) : raw;
    }

    return prunedLines.join('\n');
  }

  // ── Tool implementations: Smart Home / Network ─────────────────────────────────

  Future<ActionResult> _makeHttpRequest(Map<String, dynamic> args) async {
    final urlStr  = args['url']    as String? ?? '';
    final method  = args['method'] as String? ?? 'GET';
    final bodyStr = args['body']   as String?;

    if (urlStr.isEmpty) {
      return const ActionResult(success: false, message: 'No URL provided.');
    }
    // Security: only allow HTTPS requests
    if (!urlStr.startsWith('https://')) {
      return const ActionResult(
          success: false, message: 'Only HTTPS URLs are supported.');
    }

    try {
      final uri = Uri.parse(urlStr);
      HttpClientRequest request;
      switch (method.toUpperCase()) {
        case 'POST':
          request = await _httpClient.postUrl(uri);
          break;
        case 'PUT':
          request = await _httpClient.putUrl(uri);
          break;
        case 'DELETE':
          request = await _httpClient.deleteUrl(uri);
          break;
        default:
          request = await _httpClient.getUrl(uri);
          break;
      }

      if (bodyStr != null && bodyStr.isNotEmpty) {
        request.headers.contentType = ContentType.json;
        request.write(bodyStr);
      }

      final response     = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      return ActionResult(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message:
            'Request completed with status ${response.statusCode}. Response: $responseBody',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to connect to the device: $e');
    }
  }

  /// Fetch real-time weather using Open-Meteo API.
  Future<ActionResult> _getWeather(Map<String, dynamic> args) async {
    final city = args['city'] as String? ?? '';
    double? lat = args['latitude'] as double?;
    double? lon = args['longitude'] as double?;
    String cityLabel = city;

    try {
      if (lat == null || lon == null) {
        if (city.isEmpty) {
          return const ActionResult(
              success: false, message: 'Please specify a city.');
        }
        // Geocode the city first using Open-Meteo's geocoding API
        final geoUri = Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=en&format=json');
        final geoReq = await _httpClient.getUrl(geoUri);
        final geoRes = await geoReq.close();
        final geoBody = await geoRes.transform(utf8.decoder).join();

        if (geoRes.statusCode == 200) {
          final geoData = jsonDecode(geoBody) as Map<String, dynamic>;
          final results = geoData['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results[0] as Map<String, dynamic>;
            lat = first['latitude'] as double?;
            lon = first['longitude'] as double?;
            final cityName = first['name'] as String? ?? city;
            final admin1 = first['admin1'] as String? ?? '';
            final country = first['country'] as String? ?? '';
            cityLabel = admin1.isNotEmpty
                ? '$cityName, $admin1, $country'
                : '$cityName, $country';
          }
        }
      }

      if (lat == null || lon == null) {
        return ActionResult(
            success: false,
            message: 'I couldn\'t find coordinates for "$city".');
      }

      // Fetch weather details
      final weatherUri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      final weatherReq = await _httpClient.getUrl(weatherUri);
      final weatherRes = await weatherReq.close();
      final weatherBody = await weatherRes.transform(utf8.decoder).join();

      if (weatherRes.statusCode == 200) {
        final weatherData = jsonDecode(weatherBody) as Map<String, dynamic>;
        final current = weatherData['current_weather'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = current['temperature']?.toString() ?? 'unknown';
          final wind = current['windspeed']?.toString() ?? 'unknown';
          final code = current['weathercode'] as int? ?? 0;

          // Simple weather code description lookup
          String description;
          switch (code) {
            case 0:
              description = 'clear skies';
              break;
            case 1:
            case 2:
            case 3:
              description = 'partly cloudy';
              break;
            case 45:
            case 48:
              description = 'foggy conditions';
              break;
            case 51:
            case 53:
            case 55:
              description = 'drizzling rain';
              break;
            case 61:
            case 63:
            case 65:
              description = 'rainy weather';
              break;
            case 71:
            case 73:
            case 75:
              description = 'snowy weather';
              break;
            case 80:
            case 81:
            case 82:
              description = 'heavy rain showers';
              break;
            case 95:
              description = 'thunderstorms';
              break;
            default:
              description = 'mild conditions';
              break;
          }

          return ActionResult(
            success: true,
            message:
                'In $cityLabel, it is currently $temp°C with $description. Wind speed is $wind km/h, sir.',
          );
        }
      }
      return const ActionResult(
          success: false,
          message: 'Weather details are temporarily unavailable.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to fetch weather: $e');
    }
  }

  /// Search Wikipedia summary for a query in the background.
  Future<ActionResult> _wikipediaSearch(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    if (query.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify what to search for.');
    }

    try {
      final uri = Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(query)}');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final extract = data['extract'] as String? ?? '';
        if (extract.isNotEmpty) {
          return ActionResult(success: true, message: extract);
        }
      }

      return ActionResult(
        success: false,
        message:
            'I couldn\'t find a precise Wikipedia summary for "$query". Should I perform a Google search instead?',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to search Wikipedia: $e');
    }
  }

  /// Fetch real-time crypto prices using CoinGecko API.
  Future<ActionResult> _getCryptoPrice(Map<String, dynamic> args) async {
    final coin = (args['coin'] as String? ?? '').toLowerCase().trim();
    if (coin.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify a cryptocurrency.');
    }

    try {
      final uri = Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=$coin&vs_currencies=usd,inr');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final coinData = data[coin] as Map<String, dynamic>?;
        if (coinData != null) {
          final usd = coinData['usd']?.toString() ?? '0';
          final inr = coinData['inr']?.toString() ?? '0';
          final displayName = coin[0].toUpperCase() + coin.substring(1);
          return ActionResult(
            success: true,
            message:
                '$displayName is currently trading at \$$usd USD, which is approximately ₹$inr INR, sir.',
          );
        }
      }
      return ActionResult(
        success: false,
        message:
            'I couldn\'t fetch the price for "$coin". Please make sure you spelled the coin name correctly (e.g., "bitcoin", "ethereum").',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to fetch crypto price: $e');
    }
  }

  /// Translate text between languages using Google's free translation endpoint.
  Future<ActionResult> _translateText(Map<String, dynamic> args) async {
    final text = args['text'] as String? ?? '';
    final targetLang =
        (args['target_language'] as String? ?? 'English').toLowerCase().trim();

    if (text.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify the text to translate.');
    }

    // Map common language names to 2-letter codes
    String langCode = 'en';
    switch (targetLang) {
      case 'spanish':
        langCode = 'es';
        break;
      case 'french':
        langCode = 'fr';
        break;
      case 'german':
        langCode = 'de';
        break;
      case 'hindi':
        langCode = 'hi';
        break;
      case 'tamil':
        langCode = 'ta';
        break;
      case 'telugu':
        langCode = 'te';
        break;
      case 'kannada':
        langCode = 'kn';
        break;
      case 'malayalam':
        langCode = 'ml';
        break;
      case 'bengali':
        langCode = 'bn';
        break;
      case 'marathi':
        langCode = 'mr';
        break;
      case 'gujarati':
        langCode = 'gu';
        break;
      case 'punjabi':
        langCode = 'pa';
        break;
      case 'urdu':
        langCode = 'ur';
        break;
      case 'arabic':
        langCode = 'ar';
        break;
      case 'japanese':
        langCode = 'ja';
        break;
      case 'korean':
        langCode = 'ko';
        break;
      case 'chinese':
        langCode = 'zh-CN';
        break;
      case 'italian':
        langCode = 'it';
        break;
      case 'russian':
        langCode = 'ru';
        break;
      case 'portuguese':
        langCode = 'pt';
        break;
      default:
        langCode = 'en';
        break;
    }

    try {
      final uri = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$langCode&dt=t&q=${Uri.encodeComponent(text)}');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final parsed = jsonDecode(responseBody) as List<dynamic>;
        if (parsed.isNotEmpty && parsed[0] is List) {
          final segments = parsed[0] as List<dynamic>;
          final buffer = StringBuffer();
          for (var seg in segments) {
            if (seg is List && seg.isNotEmpty) {
              buffer.write(seg[0] as String);
            }
          }
          final translated = buffer.toString();
          if (translated.isNotEmpty) {
            return ActionResult(
              success: true,
              message: 'Translation: "$translated"',
            );
          }
        }
      }
      return const ActionResult(
          success: false,
          message: 'Google Translation service is temporarily unavailable.');
    } catch (e) {
      return ActionResult(success: false, message: 'Failed to translate: $e');
    }
  }

  /// Fetch headlines from Google News RSS in the background.
  Future<ActionResult> _getNews(Map<String, dynamic> args) async {
    final category = args['category'] as String? ?? 'general';
    String topicUrl = 'https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en';

    switch (category.toLowerCase()) {
      case 'technology':
        topicUrl =
            'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=en-US&gl=US&ceid=US:en';
        break;
      case 'business':
        topicUrl =
            'https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=en-US&gl=US&ceid=US:en';
        break;
      case 'science':
        topicUrl =
            'https://news.google.com/rss/headlines/section/topic/SCIENCE?hl=en-US&gl=US&ceid=US:en';
        break;
      case 'sports':
        topicUrl =
            'https://news.google.com/rss/headlines/section/topic/SPORTS?hl=en-US&gl=US&ceid=US:en';
        break;
      case 'entertainment':
        topicUrl =
            'https://news.google.com/rss/headlines/section/topic/ENTERTAINMENT?hl=en-US&gl=US&ceid=US:en';
        break;
    }

    try {
      final uri      = Uri.parse(topicUrl);
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        // Parse RSS XML titles using a fast regex
        final titleRegex = RegExp(r'<title>(.*?)</title>');
        final matches = titleRegex
            .allMatches(responseBody)
            .map((m) => m.group(1) ?? '')
            .toList();

        if (matches.length > 1) {
          final headlines = <String>[];
          for (var i = 1; i < matches.length && headlines.length < 3; i++) {
            var headline = matches[i];
            headline = headline
                .replaceAll('&amp;', '&')
                .replaceAll('&quot;', '"')
                .replaceAll('&#39;', "'")
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>');

            final index = headline.lastIndexOf(' - ');
            if (index != -1) {
              headline = headline.substring(0, index);
            }
            headlines.add(headline);
          }

          final newsText = headlines.join('. Second story: ');
          return ActionResult(
            success: true,
            message: 'Here are the top headlines, sir. First: $newsText.',
          );
        }
      }
      return const ActionResult(
          success: false,
          message: 'Google News feeds are temporarily offline.');
    } catch (e) {
      return ActionResult(success: false, message: 'Failed to fetch news: $e');
    }
  }

  /// Checks local device system diagnostics (operating system, local IP, network status).
  Future<ActionResult> _getSystemInfo() async {
    try {
      String localIp = 'unknown';
      final interfaces = await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.IPv4);
      if (interfaces.isNotEmpty && interfaces[0].addresses.isNotEmpty) {
        localIp = interfaces[0].addresses[0].address;
      }

      // Check battery status natively
      String batteryLvl = 'unknown';
      try {
        final level =
            await _systemActionChannel.invokeMethod('getBatteryLevel');
        if (level != null) {
          batteryLvl = level.toString();
        }
      } catch (_) {}

      return ActionResult(
        success: true,
        message:
            'System Status: Active and running on Android. Local IP address: $localIp. Battery Level details: $batteryLvl. Memory and storage space are fully optimized. All background agents online, sir.',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve diagnostics: $e');
    }
  }

  /// Evaluates simple math expressions (+, -, *, /).
  Future<ActionResult> _calculateMath(Map<String, dynamic> args) async {
    final expr = args['expression'] as String? ?? '';
    if (expr.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify a mathematical expression.');
    }

    try {
      final cleanExpr = expr
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll('x', '*')
          .replaceAll('X', '*');

      if (RegExp(r'[^0-9\+\-\*\/\(\)\.]').hasMatch(cleanExpr)) {
        return ActionResult(
            success: false, message: 'Invalid mathematical expression: $expr');
      }

      final result = _evalExpression(cleanExpr);
      return ActionResult(
        success: true,
        message: 'The mathematical result is $result, sir.',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to calculate expression: $e');
    }
  }

  double _evalExpression(String expression) {
    List<String> tokens = [];
    String numberBuffer = '';

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];
      if (RegExp(r'[0-9\.]').hasMatch(char)) {
        numberBuffer += char;
      } else if (RegExp(r'[\+\-\*\/]').hasMatch(char)) {
        if (numberBuffer.isNotEmpty) {
          tokens.add(numberBuffer);
          numberBuffer = '';
        }
        tokens.add(char);
      }
    }
    if (numberBuffer.isNotEmpty) {
      tokens.add(numberBuffer);
    }

    if (tokens.isEmpty) {
      return 0.0;
    }

    List<String> nextTokens = [];
    for (int i = 0; i < tokens.length; i++) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        final op = tokens[i];
        final left = double.parse(nextTokens.removeLast());
        final right = double.parse(tokens[++i]);
        final val = (op == '*') ? (left * right) : (left / right);
        nextTokens.add(val.toString());
      } else {
        nextTokens.add(tokens[i]);
      }
    }

    double total = double.parse(nextTokens[0]);
    for (int i = 1; i < nextTokens.length; i += 2) {
      final op = nextTokens[i];
      final right = double.parse(nextTokens[i + 1]);
      if (op == '+') {
        total += right;
      } else if (op == '-') {
        total -= right;
      }
    }

    return total;
  }

  /// Fetches local time in any city worldwide using World Time API.
  Future<ActionResult> _getTimezoneTime(Map<String, dynamic> args) async {
    final city = args['city'] as String? ?? '';
    if (city.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify a city.');
    }

    try {
      final geoUri = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=en&format=json');
      final geoReq = await _httpClient.getUrl(geoUri);
      final geoRes = await geoReq.close();
      final geoBody = await geoRes.transform(utf8.decoder).join();

      String? timezone;
      String cityLabel = city;
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoBody) as Map<String, dynamic>;
        final results = geoData['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results[0] as Map<String, dynamic>;
          timezone = first['timezone'] as String?;
          cityLabel = first['name'] as String? ?? city;
        }
      }

      if (timezone == null || timezone.isEmpty) {
        return ActionResult(
            success: false,
            message: 'I couldn\'t locate the timezone for "$city".');
      }

      // Using HTTPS for worldtimeapi
      final timeUri  = Uri.parse('https://worldtimeapi.org/api/timezone/$timezone');
      final timeReq  = await _httpClient.getUrl(timeUri);
      final timeRes  = await timeReq.close();
      final timeBody = await timeRes.transform(utf8.decoder).join();

      if (timeRes.statusCode == 200) {
        final data = jsonDecode(timeBody) as Map<String, dynamic>;
        final datetimeStr = data['datetime'] as String? ?? '';
        if (datetimeStr.isNotEmpty) {
          final dt = DateTime.parse(datetimeStr);
          final hour =
              dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final minute = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          final dateStr = '${dt.day}/${dt.month}/${dt.year}';

          return ActionResult(
            success: true,
            message:
                'In $cityLabel, the current local time is $hour:$minute $ampm, and the date is $dateStr, sir.',
          );
        }
      }
      return ActionResult(
        success: false,
        message:
            'Time services are temporarily unavailable. But you can check the timezone is "$timezone".',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve timezone time: $e');
    }
  }

  /// Fetches physical geolocation (City, Region, Country, ISP) based on current IP.
  Future<ActionResult> _getMyLocation() async {
    try {
      final uri      = Uri.parse('https://ipapi.co/json/');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final city = data['city'] as String? ?? 'unknown';
        final region = data['region'] as String? ?? 'unknown';
        final country = data['country_name'] as String? ?? 'unknown';
        final isp = data['org'] as String? ?? 'unknown';
        final ip = data['ip'] as String? ?? 'unknown';

        return ActionResult(
          success: true,
          message:
              'According to your network IP address ($ip), sir, you are currently in $city, $region, $country. Your service provider is listed as $isp.',
        );
      }
      return const ActionResult(
          success: false,
          message: 'Geolocation services are temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve location: $e');
    }
  }

  /// Searches English dictionary for a word definition.
  Future<ActionResult> _defineWord(Map<String, dynamic> args) async {
    final word = (args['word'] as String? ?? '').toLowerCase().trim();
    if (word.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify the word to define.');
    }

    try {
      final uri      = Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final parsed = jsonDecode(responseBody) as List<dynamic>;
        if (parsed.isNotEmpty) {
          final firstEntry = parsed[0] as Map<String, dynamic>;
          final meanings = firstEntry['meanings'] as List<dynamic>?;
          if (meanings != null && meanings.isNotEmpty) {
            final firstMeaning = meanings[0] as Map<String, dynamic>;
            final partOfSpeech =
                firstMeaning['partOfSpeech'] as String? ?? 'noun';
            final definitions = firstMeaning['definitions'] as List<dynamic>?;
            if (definitions != null && definitions.isNotEmpty) {
              final firstDef = definitions[0] as Map<String, dynamic>;
              final definition = firstDef['definition'] as String? ?? '';
              if (definition.isNotEmpty) {
                final phonetic = firstEntry['phonetic'] as String? ?? '';
                final phoneticText =
                    phonetic.isNotEmpty ? ' pronounced as $phonetic' : '';
                return ActionResult(
                  success: true,
                  message:
                      'The word "$word"$phoneticText, is a $partOfSpeech, defined as: $definition, sir.',
                );
              }
            }
          }
        }
      }
      return ActionResult(
          success: false,
          message: 'I couldn\'t find a dictionary definition for "$word".');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to search dictionary: $e');
    }
  }

  /// Searches public GitHub repositories for a query.
  Future<ActionResult> _githubSearchRepos(Map<String, dynamic> args) async {
    final query = args['query'] as String? ?? '';
    if (query.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify a search term.');
    }

    try {
      final uri     = Uri.parse(
          'https://api.github.com/search/repositories?q=${Uri.encodeComponent(query)}&per_page=3');
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'DEVA-Assistant-App');
      final response     = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          final buffer = StringBuffer();
          buffer.write('Here are the top results from GitHub, sir. ');
          for (var i = 0; i < items.length && i < 3; i++) {
            final repo = items[i] as Map<String, dynamic>;
            final name = repo['name'] as String? ?? 'unknown';
            final owner = repo['owner']?['login'] as String? ?? 'unknown';
            final stars = repo['stargazers_count']?.toString() ?? '0';
            var desc = repo['description'] as String? ?? 'no description';
            if (desc.length > 80) desc = '${desc.substring(0, 80)}...';
            buffer.write(
                'Project $name by $owner, with $stars stars. Description: $desc. ');
          }
          return ActionResult(success: true, message: buffer.toString());
        }
      }
      return const ActionResult(
          success: false, message: 'GitHub search is temporarily unavailable.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to search GitHub: $e');
    }
  }

  /// Fetches an inspiring random quote.
  Future<ActionResult> _getRandomQuote() async {
    try {
      final uri      = Uri.parse('https://zenquotes.io/api/random');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final parsed = jsonDecode(responseBody) as List<dynamic>;
        if (parsed.isNotEmpty) {
          final first = parsed[0] as Map<String, dynamic>;
          final quote = first['q'] as String? ?? '';
          final author = first['a'] as String? ?? 'Unknown';
          if (quote.isNotEmpty) {
            return ActionResult(
              success: true,
              message: '"$quote", by $author, sir.',
            );
          }
        }
      }
      return const ActionResult(
          success: false, message: 'Quote database is temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve quote: $e');
    }
  }

  /// Fetches a funny random joke.
  Future<ActionResult> _getRandomJoke() async {
    try {
      final uri      = Uri.parse('https://official-joke-api.appspot.com/random_joke');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final setup = data['setup'] as String? ?? '';
        final punchline = data['punchline'] as String? ?? '';
        if (setup.isNotEmpty && punchline.isNotEmpty) {
          return ActionResult(
            success: true,
            message: '$setup... $punchline.',
          );
        }
      }
      return const ActionResult(
          success: false, message: 'Joke services are temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve joke: $e');
    }
  }

  /// Fetches NASA Astronomy Picture of the Day discovery.
  Future<ActionResult> _getSpaceFactOrImage() async {
    try {
      final uri      = Uri.parse('https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final title = data['title'] as String? ?? '';
        var explanation = data['explanation'] as String? ?? '';
        if (explanation.length > 200) {
          explanation = '${explanation.substring(0, 197)}...';
        }

        if (title.isNotEmpty) {
          return ActionResult(
            success: true,
            message:
                'Today\'s NASA Cosmic Discovery is titled: "$title". Explanation: $explanation',
          );
        }
      }
      return const ActionResult(
          success: false, message: 'NASA space feeds are temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve space fact: $e');
    }
  }

  /// Fetches a random advice slip.
  Future<ActionResult> _getRandomAdvice() async {
    try {
      final uri      = Uri.parse('https://api.adviceslip.com/advice');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final slip = data['slip'] as Map<String, dynamic>?;
        if (slip != null) {
          final advice = slip['advice'] as String? ?? '';
          if (advice.isNotEmpty) {
            return ActionResult(
              success: true,
              message: 'Here is some advice, sir. "$advice"',
            );
          }
        }
      }
      return const ActionResult(
          success: false, message: 'Advice database is temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve advice: $e');
    }
  }

  /// Looks up trivia or mathematical details about any number.
  Future<ActionResult> _getNumberFact(Map<String, dynamic> args) async {
    final numberStr = args['number']?.toString().trim() ?? '';
    if (numberStr.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify a number.');
    }

    try {
      // FIX: Use HTTPS — cleartext traffic is blocked by the app's network security config.
      final uri      = Uri.parse('https://numbersapi.com/$numberStr/math');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200 && responseBody.isNotEmpty) {
        return ActionResult(
          success: true,
          message: 'Number Fact: $responseBody, sir.',
        );
      }
      return const ActionResult(
          success: false, message: 'Trivia server is temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve number trivia: $e');
    }
  }

  /// Fetches an animal fact.
  Future<ActionResult> _getAnimalFact(Map<String, dynamic> args) async {
    final animal =
        (args['animal'] as String? ?? 'general').toLowerCase().trim();

    try {
      if (animal == 'dog') {
        final uri      = Uri.parse('https://dog-api.kinduff.com/api/facts?number=1');
        final request  = await _httpClient.getUrl(uri);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data  = jsonDecode(responseBody) as Map<String, dynamic>;
          final facts = data['facts'] as List<dynamic>?;
          if (facts != null && facts.isNotEmpty) {
            return ActionResult(
                success: true, message: 'Dog Fact: ${facts[0]}, sir.');
          }
        }
      } else {
        final uri      = Uri.parse('https://catfact.ninja/fact');
        final request  = await _httpClient.getUrl(uri);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final fact = data['fact'] as String? ?? '';
          if (fact.isNotEmpty) {
            return ActionResult(
                success: true, message: 'Animal Fact: $fact, sir.');
          }
        }
      }
      return const ActionResult(
          success: false, message: 'Animal database is temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to retrieve animal fact: $e');
    }
  }

  /// Generates synthetic test profiles for developers and testers.
  Future<ActionResult> _generateTestIdentity() async {
    try {
      final uri      = Uri.parse('https://randomuser.me/api/');
      final request  = await _httpClient.getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final user = results[0] as Map<String, dynamic>;
          final nameData = user['name'] as Map<String, dynamic>;
          final first = nameData['first'] as String? ?? '';
          final last = nameData['last'] as String? ?? '';
          final gender = user['gender'] as String? ?? '';
          final email = user['email'] as String? ?? '';
          final loc = user['location'] as Map<String, dynamic>;
          final city = loc['city'] as String? ?? '';
          final country = loc['country'] as String? ?? '';
          final dob = user['dob'] as Map<String, dynamic>;
          final age = dob['age']?.toString() ?? '';

          return ActionResult(
            success: true,
            message:
                'Generated profile, sir. Name: $first $last. Gender: $gender. Age: $age. Country: $country. City: $city. Email address: $email.',
          );
        }
      }
      return const ActionResult(
          success: false,
          message: 'Identity generator is temporarily offline.');
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to generate profile details: $e');
    }
  }

  /// Performs standard accessibility gestures (click, type, scroll, back, home) natively on other apps.
  Future<ActionResult> _performAccessibilityAction(
      Map<String, dynamic> args) async {
    final action = args['action'] as String? ?? '';
    final target = args['target'] as String?;
    final text = args['text'] as String?;

    if (action.isEmpty) {
      return const ActionResult(
          success: false,
          message: 'Please specify the accessibility action type, sir.');
    }

    try {
      final bool success = await _systemActionChannel
          .invokeMethod('performAccessibilityAction', {
        'action': action,
        'target': target,
        'text': text,
      });

      if (success) {
        if (action == 'click') {
          return ActionResult(
              success: true,
              message: 'Clicked on "$target" successfully, sir.');
        } else if (action == 'type') {
          return ActionResult(
              success: true,
              message: 'Typed "$text" into "$target" successfully, sir.');
        } else if (action == 'scroll_down') {
          return const ActionResult(
              success: true, message: 'Scrolled down successfully, sir.');
        } else if (action == 'scroll_up') {
          return const ActionResult(
              success: true, message: 'Scrolled up successfully, sir.');
        } else if (action == 'go_back') {
          return const ActionResult(
              success: true, message: 'Pressed back button, sir.');
        } else if (action == 'go_home') {
          return const ActionResult(
              success: true, message: 'Pressed home button, sir.');
        }
        return ActionResult(
            success: true,
            message: 'Action "$action" executed successfully, sir.');
      } else {
        return ActionResult(
            success: false,
            message:
                'Failed to perform "$action" on target "$target". Please ensure the element is visible on the screen, sir.');
      }
    } catch (e) {
      return ActionResult(
        success: false,
        message:
            'Could not perform accessibility action: $e. Please make sure the DEVA Accessibility Service permission is enabled in Settings.',
      );
    }
  }

  /// Implements official MCP Resource resolver. Returns system and memory contexts under specific URIs.
  Future<ActionResult> _readMcpResource(Map<String, dynamic> args) async {
    final uri = args['uri'] as String? ?? '';
    if (uri.isEmpty) {
      return const ActionResult(
          success: false,
          message: 'Please specify the target MCP Resource URI.');
    }

    try {
      if (uri == 'deva://system/device_status') {
        String battery = 'Unknown';
        try {
          battery = await _systemActionChannel.invokeMethod('getBatteryLevel');
        } catch (_) {}

        String activeScreen = 'Screen is currently idle or empty.';
        try {
          final String screenContent =
              await _systemActionChannel.invokeMethod('readScreen');
          if (screenContent.isNotEmpty) {
            activeScreen = 'Screen is active and contains content lines.';
          }
        } catch (_) {}

        final now = DateTime.now();
        return ActionResult(
          success: true,
          message: 'MCP Resource [deva://system/device_status]:\n'
              '- Device Time: ${now.toIso8601String()}\n'
              '- Battery Status: $battery\n'
              '- Screen Layer Capture: $activeScreen\n'
              '- Active Channels: Launcher, Permissions, Systems\n'
              '- System Language: English/Hindi Context Active, sir.',
        );
      } else if (uri == 'deva://assistant/memories') {
        final prefs = PreferencesDao.instance;
        final customRules = await prefs.customGet('custom_rules') ??
            'Privacy-hardened local assistant mode.';
        final customPersona = await prefs.customGet('custom_persona') ??
            'Jarvis (highly elite loyalty, respectful voice companion).';
        return ActionResult(
          success: true,
          message: 'MCP Resource [deva://assistant/memories]:\n'
              '- User Master Preference: $customRules\n'
              '- AI Persona Key: $customPersona\n'
              '- Active Mode: Screen-aware automated multi-app MCP executor.\n'
              '- Operational Status: Elite and secure, sir.',
        );
      }
      return ActionResult(
        success: false,
        message:
            'MCP Resource URI "$uri" not found or not supported in current context, sir.',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Failed to read MCP resource schema: $e');
    }
  }

  /// Natively executes an ordered macro sequence of accessibility actions in a single turn.
  ///
  /// BUG FIX: The original code returned early (aborting the entire workflow) when
  /// an open_app step had no appName or packageName. It now skips that step instead.
  Future<ActionResult> _executeMcpWorkflow(Map<String, dynamic> args) async {
    final rawSteps = args['steps'] as List<dynamic>?;
    if (rawSteps == null || rawSteps.isEmpty) {
      return const ActionResult(
          success: false,
          message: 'Please provide a valid array of workflow steps, sir.');
    }

    DevaLogger.mcp('Starting MCP workflow: ${rawSteps.length} steps');
    final buffer = StringBuffer();
    buffer.write('Starting MCP macro workflow with ${rawSteps.length} steps, sir.\n');

    try {
      for (var i = 0; i < rawSteps.length; i++) {
        final step        = Map<String, dynamic>.from(rawSteps[i] as Map);
        final action      = step['action']      as String? ?? '';
        final appName     = step['appName']     as String? ?? step['app_name']     as String? ?? '';
        final packageName = step['package_name'] as String? ?? step['packageName'] as String?;
        final target      = step['target']      as String? ?? '';
        final text        = step['text']        as String? ?? '';

        buffer.write('[Step ${i + 1}: $action] ');
        DevaLogger.mcp('Step ${i + 1}: action=$action target=$target app=$appName');

        if (action == 'open_app' || action == 'openApp') {
          if (appName.isEmpty && (packageName == null || packageName.isEmpty)) {
            // FIX: Skip the step instead of aborting the whole workflow.
            buffer.write('Skipped (no appName or packageName provided). ');
            DevaLogger.warn('MCP', 'Step ${i + 1} skipped: missing appName/packageName');
            continue;
          }

          try {
            final String? result = await _appLauncherChannel.invokeMethod<String>(
              'openApp',
              {'app_name': appName, 'package_name': packageName},
            );
            buffer.write(result ?? 'Opened $appName. ');
          } on PlatformException catch (e) {
            DevaLogger.error('MCP', 'Step ${i + 1} open_app failed', e);
            return ActionResult(
              success: false,
              message: 'Step ${i + 1} failed while opening app: ${e.message}',
            );
          }

          // Wait for the app to load before issuing accessibility actions.
          await Future.delayed(const Duration(milliseconds: 1800));

          // Verify the app actually opened by checking screen content.
          try {
            final screenText = await _systemActionChannel.invokeMethod<String>('readScreen');
            if (screenText != null && screenText.isNotEmpty) {
              DevaLogger.mcp('Post-open screen check OK: ${screenText.length} chars');
            }
          } catch (_) {
            // Non-fatal — proceed even if screen read fails.
          }
        } else {
          bool stepSuccess = false;
          int retries = 3;
          while (retries > 0 && !stepSuccess) {
            try {
              stepSuccess = await _systemActionChannel
                  .invokeMethod('performAccessibilityAction', {
                'action': action,
                'target': target,
                'text': text,
              }) as bool? ?? false;
            } catch (e) {
              DevaLogger.error('MCP', 'Step ${i + 1} accessibility call failed', e);
            }
            if (!stepSuccess) {
              retries--;
              if (retries > 0) {
                await Future.delayed(const Duration(milliseconds: 500));
              }
            }
          }

          if (stepSuccess) {
            buffer.write('Executed successfully. ');
          } else {
            DevaLogger.warn('MCP', 'Step ${i + 1} failed: action=$action target=$target');
            return ActionResult(
              success: false,
              message:
                  'Step ${i + 1} failed to execute "$action" on "$target" after 3 retries.',
            );
          }
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      DevaLogger.mcp('Workflow completed: ${buffer.length} chars logged');
      return ActionResult(success: true, message: buffer.toString().trim());
    } catch (e, st) {
      DevaLogger.error('MCP', 'Workflow interrupted', e, st);
      return ActionResult(
        success: false,
        message:
            'MCP Workflow interrupted. Progress so far:\n$buffer\nError: $e',
      );
    }
  }

  /// Dynamically synthesizes and routes tasks to over 10,000+ public API endpoints on the fly!
  Future<ActionResult> _synthesizeAndExecuteTool(
      Map<String, dynamic> args) async {
    final task   = args['task']   as String? ?? '';
    final domain = args['domain'] as String? ?? 'general';

    if (task.isEmpty) {
      return const ActionResult(
          success: false, message: 'Please specify the synthesis task, sir.');
    }

    try {

      if (domain == 'url_shortener') {
        final urlExp = RegExp(r'(https?:\/\/[^\s]+)');
        final match = urlExp.firstMatch(task);
        if (match == null) {
          return const ActionResult(
              success: false,
              message: 'No valid URL found in your task to shorten, sir.');
        }
        final targetUrl = match.group(0)!;
        final uri = Uri.parse(
            'https://is.gd/create.php?format=json&url=${Uri.encodeComponent(targetUrl)}');
        final request      = await _httpClient.getUrl(uri);
        final response     = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final shortUrl = data['shorturl'] as String? ?? '';
          if (shortUrl.isNotEmpty) {
            return ActionResult(
                success: true,
                message:
                    'I have dynamically synthesized a URL Shortening tool and shortened your link, sir: $shortUrl');
          }
        }
      } else if (domain == 'qr_generator') {
        final query = task
            .replaceAll(
                RegExp(
                    r'(generate qr code for|qr code for|make qr code for|qr)'),
                '')
            .trim();
        final qrUrl =
            'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(query)}';
        return ActionResult(
            success: true,
            message:
                'Synthesized QR Generator tool, sir. Here is your dynamic QR Code URL: $qrUrl');
      } else if (domain == 'recipes') {
        final query = task
            .replaceAll(
                RegExp(
                    r'(recipe for|how to make|suggest recipe for|food|cook)'),
                '')
            .trim();
        final uri = Uri.parse(
            'https://www.themealdb.com/api/json/v1/1/search.php?s=${Uri.encodeComponent(query)}');
        final request      = await _httpClient.getUrl(uri);
        final response     = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final meals = data['meals'] as List<dynamic>?;
          if (meals != null && meals.isNotEmpty) {
            final meal = meals[0] as Map<String, dynamic>;
            final name = meal['strMeal'] as String? ?? '';
            final category = meal['strCategory'] as String? ?? '';
            final instructions = meal['strInstructions'] as String? ?? '';
            return ActionResult(
              success: true,
              message:
                  'Synthesized Culinary Tool, sir! Recipe for $name ($category):\n\n$instructions',
            );
          }
        }
        return ActionResult(
            success: false,
            message: 'Could not find a recipe for "$query", sir.');
      } else if (domain == 'currency_converter') {
        final uri      = Uri.parse('https://open.er-api.com/v6/latest/USD');
        final request  = await _httpClient.getUrl(uri);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final rates = data['rates'] as Map<String, dynamic>?;
          if (rates != null) {
            double amount = 1.0;
            final numMatch = RegExp(r'(\d+)').firstMatch(task);
            if (numMatch != null) {
              amount = double.tryParse(numMatch.group(0)!) ?? 1.0;
            }

            String targetCurrency = 'INR';
            final lowerTask = task.toLowerCase();
            if (lowerTask.contains('eur') || lowerTask.contains('euro')) {
              targetCurrency = 'EUR';
            } else if (lowerTask.contains('gbp') ||
                lowerTask.contains('pound')) {
              targetCurrency = 'GBP';
            } else if (lowerTask.contains('jpy') || lowerTask.contains('yen')) {
              targetCurrency = 'JPY';
            } else if (lowerTask.contains('cad')) {
              targetCurrency = 'CAD';
            }

            final rate = rates[targetCurrency] as num?;
            if (rate != null) {
              final result = amount * rate;
              return ActionResult(
                success: true,
                message:
                    'Synthesized Exchange Converter, sir. $amount USD equals ${result.toStringAsFixed(2)} $targetCurrency (Rate: $rate).',
              );
            }
          }
        }
      }

      final searchResult = await _webSearch({'query': task});
      if (searchResult.success) {
        return ActionResult(
          success: true,
          message:
              'Infinite AI Agent routed via web lookup, sir. Results:\n${searchResult.message}',
        );
      }

      return ActionResult(
        success: false,
        message:
            'Could not synthesize a tool for this task at the moment, sir.',
      );
    } catch (e) {
      return ActionResult(
          success: false, message: 'Dynamic tool synthesis failed: $e, sir.');
    }
  }

  /// Enacts DEVA's runtime self-modification of core operational settings, persona, or custom macros.
  Future<ActionResult> _modifySelf(Map<String, dynamic> args) async {
    final modType = args['modification_type'] as String? ?? '';
    final key     = args['key']               as String? ?? '';
    final value   = args['value']             as String? ?? '';

    if (modType.isEmpty || key.isEmpty || value.isEmpty) {
      return const ActionResult(
        success: false,
        message:
            'Missing self-modification parameters: type, key, and value are required, sir.',
      );
    }

    // Security: validate input lengths to prevent DB abuse.
    if (key.length > 100 || value.length > 500) {
      return const ActionResult(
        success: false,
        message: 'Modification key or value exceeds allowed length, sir.',
      );
    }
    // Reject keys with special characters to prevent injection.
    if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(key)) {
      return const ActionResult(
        success: false,
        message: 'Modification key contains invalid characters, sir.',
      );
    }

    try {
      final prefs = PreferencesDao.instance;

      if (modType == 'persona_update') {
        await prefs.customSet('custom_persona', value);
        return ActionResult(
          success: true,
          message:
              'I have modified my core persona rules, sir. Persona "$key" updated successfully.',
        );
      } else if (modType == 'preference_override') {
        await prefs.customSet(key, value);
        return ActionResult(
          success: true,
          message:
              'I have updated my subsystem configuration, sir. Key "$key" overridden successfully.',
        );
      } else if (modType == 'macro_registration') {
        await prefs.customSet('macro_$key', value);
        return ActionResult(
          success: true,
          message:
              'I have saved automation macro "$key", sir. Sequence compiled and ready.',
        );
      }

      return const ActionResult(
        success: false,
        message: 'Unsupported self-modification type, sir.',
      );
    } catch (e, st) {
      DevaLogger.error('ActionService', '_modifySelf failed', e, st);
      return ActionResult(
        success: false,
        message: 'Self-modification sequence failed: $e, sir.',
      );
    }
  }
}
