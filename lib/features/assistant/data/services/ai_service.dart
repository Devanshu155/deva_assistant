/// AI Service — communicates with Groq API (OpenAI-compatible).
/// Security: API key retrieved from secure storage (Android Keystore).
/// Privacy: Only the voice transcript is sent — no device data, no identity.
library;

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../domain/tools/tool_definitions.dart';
import '../../../../shared/services/secure_storage_service.dart';
import '../../../../shared/database/memory_dao.dart';
import '../../../../core/constants/app_constants.dart';

/// Result from the AI service containing the text response and optional tool call.
class AiResponse {
  final String text; // Spoken response text
  final String? toolName; // Tool to execute (null if none)
  final Map<String, dynamic>? toolArgs; // Tool arguments
  final String?
      detectedLangCode; // BCP-47 language of the AI response (e.g. "hi-IN")

  const AiResponse({
    required this.text,
    this.toolName,
    this.toolArgs,
    this.detectedLangCode,
  });

  bool get hasToolCall => toolName != null;
}

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  final _secure = SecureStorageService.instance;
  final _memory = MemoryDao.instance;

  // In-session conversation history (cleared on app restart — privacy by design)
  final List<Map<String, String>> _conversationHistory = [];

  // ── Main entry point ──────────────────────────────────────────────────

  /// Send a voice command to Groq and get a structured response.
  /// Only the [userText] is transmitted — no personal data.
  Future<AiResponse> sendCommand(String userText) async {
    final apiKey = await _secure.getGroqApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const AiResponse(
        text:
            'I need an Activation Code to work. Please activate me in Settings.',
      );
    }

    // Build messages: system prompt + local memory context + history + new turn
    final messages = await _buildMessages(userText);

    // Determine route: Proxy vs Direct
    final useProxy = AppConstants.proxyBaseUrl.isNotEmpty;
    final endpoint = useProxy
        ? AppConstants.proxyBaseUrl
        : '${AppConstants.groqBaseUrl}/chat/completions';

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Only attach the API key locally if we are connecting directly to Groq.
    // If using the proxy, the proxy attaches the key securely in the cloud.
    if (!useProxy) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode({
              'model': AppConstants.groqModel,
              'messages': messages,
              'tools': DevaTools.allAsJson,
              'tool_choice': 'auto',
              'max_tokens': AppConstants.groqMaxTokens,
              'temperature': AppConstants.groqTemp,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = _parseResponse(data, userText);
        // Append to in-session history (never persisted — privacy by design)
        _appendToHistory(userText, result.text);
        return result;
      } else {
        debugPrint('[AI] Groq error ${response.statusCode}: ${response.body}');
        // Defensive: Clear in-memory history on failure so a malformed XML turn cannot poison future prompts
        _conversationHistory.clear();

        // Try to extract the actual error message from Groq's response
        String errorDetail = '';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final errorObj = errorData['error'] as Map<String, dynamic>?;
          errorDetail = errorObj?['message'] as String? ?? '';

          final failedGen =
              errorObj?['failed_generation'] ?? errorData['failed_generation'];
          if (failedGen != null) {
            errorDetail += '\n\nGenerated output:\n$failedGen';
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          return const AiResponse(
            text:
                'My API key appears to be invalid. Please update it in Settings.',
          );
        }
        return AiResponse(
          text: errorDetail.isNotEmpty
              ? 'I hit a problem: $errorDetail'
              : 'I encountered an error (code ${response.statusCode}). Please check Settings.',
        );
      }
    } on TimeoutException catch (e) {
      debugPrint('[AI] Groq request timeout: $e');
      return const AiResponse(
        text:
            'I timed out waiting for a response, sir. Please check your connection.',
      );
    } catch (e) {
      debugPrint('[AI] Network error: $e');
      return const AiResponse(
        text:
            'I could not reach my brain right now. Please check your internet connection.',
      );
    }
  }

  // ── Message builder ───────────────────────────────────────────────────

  Future<List<Map<String, String>>> _buildMessages(String userText) async {
    // Fetch local memory context to personalise responses
    final memoryContext = await _memory.buildContextString();

    final systemContent = memoryContext.isEmpty
        ? AppConstants.systemPrompt
        : '${AppConstants.systemPrompt}\n\n$memoryContext';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemContent},
    ];

    // Add recent conversation history (limited to avoid token waste)
    final recentHistory = _conversationHistory.length >
            AppConstants.maxContextTurns
        ? _conversationHistory
            .sublist(_conversationHistory.length - AppConstants.maxContextTurns)
        : List.of(_conversationHistory);

    messages.addAll(recentHistory);

    // Add the new user turn
    messages.add({'role': 'user', 'content': userText});

    return messages;
  }

  // ── Response parser ───────────────────────────────────────────────────

  AiResponse _parseResponse(Map<String, dynamic> data, String userText) {
    try {
      final choices = data['choices'] as List<dynamic>;
      if (choices.isEmpty) {
        return const AiResponse(
            text: 'I received an empty response. Please try again.');
      }

      final message = choices[0]['message'] as Map<String, dynamic>;
      final textContent = (message['content'] as String?) ?? '';

      // Check for tool calls
      final toolCalls = message['tool_calls'] as List<dynamic>?;
      if (toolCalls != null && toolCalls.isNotEmpty) {
        final toolCall = toolCalls[0];
        final fn = toolCall['function'] as Map<String, dynamic>;
        final toolName = fn['name'] as String;

        Map<String, dynamic> toolArgs = {};
        try {
          toolArgs =
              jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;
        } catch (_) {
          debugPrint('[AI] Failed to parse tool args: ${fn['arguments']}');
        }

        return AiResponse(
          text: textContent.isNotEmpty ? textContent : 'Done!',
          toolName: toolName,
          toolArgs: toolArgs,
          detectedLangCode: _detectLanguage(textContent),
        );
      }

      return AiResponse(
        text: textContent.isNotEmpty ? textContent : 'I have nothing to say.',
        detectedLangCode: _detectLanguage(textContent),
      );
    } catch (e) {
      debugPrint('[AI] Parse error: $e');
      return const AiResponse(
          text: 'I had trouble understanding that response.');
    }
  }

  // ── History management ────────────────────────────────────────────────

  /// Append this conversation turn to the in-session history.
  void _appendToHistory(String userText, String aiText) {
    _conversationHistory
      ..add({'role': 'user', 'content': userText})
      ..add({'role': 'assistant', 'content': aiText});
  }

  /// Detect the language of a text response using simple Unicode script checks.
  /// Returns a BCP-47 language code, or null if English/unknown.
  String? _detectLanguage(String text) {
    if (text.isEmpty) return null;
    // Check for Devanagari (Hindi, Marathi, etc.)
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN';
    // Arabic
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar-SA';
    // Chinese
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) return 'zh-CN';
    // Japanese (Hiragana/Katakana)
    if (RegExp(r'[\u3040-\u30FF]').hasMatch(text)) return 'ja-JP';
    // Korean
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(text)) return 'ko-KR';
    // Tamil
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'ta-IN';
    // Telugu
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'te-IN';
    // Default — don't switch TTS language
    return null;
  }

  /// Clear in-session history (e.g., when user says "forget our conversation").
  void clearSessionHistory() => _conversationHistory.clear();
}
