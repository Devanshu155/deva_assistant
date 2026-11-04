/// Settings screen — voice preferences, API key, data management.
/// All data stays local. API key stored in Android Keystore.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../../../../shared/services/secure_storage_service.dart';
import '../../../../shared/database/preferences_dao.dart';
import '../../../../shared/database/history_dao.dart';
import '../../../../shared/database/memory_dao.dart';
import '../../../../shared/services/voice_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../assistant/presentation/providers/assistant_provider.dart';

// Use the shared channel constant — never hardcode channel names.
const _systemChannel = MethodChannel(AppConstants.channelSystemAction);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final _prefs  = PreferencesDao.instance;
  final _secure = SecureStorageService.instance;
  final _voice  = VoiceService.instance;

  final _apiKeyCtrl = TextEditingController();

  double _speechRate   = AppConstants.defaultSpeechRate;
  double _pitch        = AppConstants.defaultTtsPitch;
  double _volume       = AppConstants.defaultTtsVolume;
  bool   _haptic       = true;
  bool   _apiKeySet    = false;
  bool   _showApiKey   = false;
  bool   _overlayGranted      = false;
  bool   _notificationGranted = false;
  bool   _accessibilityGranted = false;
  bool   _usageAccessGranted  = false;
  String _selectedLang = 'auto';

  /// Guards against multiple simultaneous permission-settings navigations.
  bool _navigatingToSettings = false;
  String? _pendingPermissionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_navigatingToSettings && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking permissions...'),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      // User returned from Android Settings — re-check all permissions.
      _loadSettings().then((_) {
        if (!mounted) return;
        if (_navigatingToSettings) {
          bool isGranted = false;
          if (_pendingPermissionId == 'notification') {
            isGranted = _notificationGranted;
          } else if (_pendingPermissionId == 'accessibility') {
            isGranted = _accessibilityGranted;
          } else if (_pendingPermissionId == 'usage_access') {
            isGranted = _usageAccessGranted;
          }

          if (!isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission not granted. Please try again.'),
                backgroundColor: AppColors.redError,
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() {
            _navigatingToSettings = false;
            _pendingPermissionId = null;
          });
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final rate    = await _prefs.getSpeechRate();
      final pitch   = await _prefs.getTtsPitch();
      final vol     = await _prefs.getTtsVolume();
      final haptic  = await _prefs.getHapticFeedback();
      final hasKey  = await _secure.hasGroqApiKey();
      final overlay = await ref.read(assistantProvider.notifier).hasOverlayPermission();
      final lang    = await _prefs.getVoiceLanguage();

      // Read all permission statuses in one native call.
      Map<String, dynamic> statuses = {};
      try {
        final raw = await _systemChannel.invokeMethod<Map>('getPermissionStatuses');
        statuses = Map<String, dynamic>.from(raw ?? {});
      } catch (e) {
        debugPrint('[Settings] Could not fetch permission statuses: $e');
      }

      if (!mounted) return;
      setState(() {
        _speechRate          = rate;
        _pitch               = pitch;
        _volume              = vol;
        _haptic              = haptic;
        _apiKeySet           = hasKey;
        _overlayGranted      = overlay;
        _selectedLang        = lang ?? 'auto';
        _notificationGranted = statuses['notification'] as bool? ?? false;
        _accessibilityGranted = statuses['accessibility'] as bool? ?? false;
        _usageAccessGranted  = statuses['usage_access'] as bool? ?? false;
      });
    } catch (e) {
      debugPrint('[Settings] _loadSettings error: $e');
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    await _secure.saveGroqApiKey(key);
    _apiKeyCtrl.clear();
    setState(() => _apiKeySet = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved securely in device keystore.'),
          backgroundColor: AppColors.greenAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Opens a system settings page identified by [settingsMethodName].
  ///
  /// Shows a loading indicator on the button while navigating, so the user
  /// never sees a dead/black screen with no feedback. On return, permission
  /// statuses are refreshed automatically via [didChangeAppLifecycleState].
  Future<void> _openSettingsPage(String settingsMethodName, String permissionId) async {
    if (_navigatingToSettings) return;

    setState(() {
      _navigatingToSettings = true;
      _pendingPermissionId = permissionId;
    });
    try {
      final result = await _systemChannel.invokeMethod<bool>(settingsMethodName);
      if (result != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open settings. Please navigate manually.'),
            backgroundColor: AppColors.redError,
          ),
        );
        setState(() {
          _navigatingToSettings = false;
          _pendingPermissionId = null;
        });
      }
      // On success: user is now in Android Settings.
      // _navigatingToSettings resets to false in didChangeAppLifecycleState(resumed).
    } on PlatformException catch (e) {
      debugPrint('[Settings] $settingsMethodName error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening settings: ${e.message}'),
            backgroundColor: AppColors.redError,
          ),
        );
        setState(() {
          _navigatingToSettings = false;
          _pendingPermissionId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Settings',
            style: AppTypography.headingSmall.copyWith(letterSpacing: 2)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _sectionHeader('ACTIVATION'),
          _apiKeySection(),
          const SizedBox(height: 20),
          _sectionHeader('VOICE'),
          _voiceSection(),
          const SizedBox(height: 20),
          _sectionHeader('LANGUAGE'),
          _languageSection(),
          const SizedBox(height: 20),
          _sectionHeader('PERMISSIONS'),
          _permissionsSection(),
          const SizedBox(height: 20),
          _sectionHeader('PRIVACY & DATA'),
          _privacySection(),
          const SizedBox(height: 20),
          _sectionHeader('ABOUT'),
          _aboutSection(),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
        child: Text(title,
            style: AppTypography.neonLabel
                .copyWith(fontSize: 11, letterSpacing: 3)),
      );

  // ── Glass card wrapper ────────────────────────────────────────────────
  Widget _glassCard(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: child,
            ),
          ),
        ),
      );

  // ── API Key section ───────────────────────────────────────────────────
  Widget _apiKeySection() => _glassCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_apiKeySet ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: _apiKeySet ? AppColors.greenAccent : AppColors.textHint,
                size: 18),
            const SizedBox(width: 8),
            Text(_apiKeySet ? 'Activated successfully' : 'Not activated',
                style: AppTypography.bodyMedium.copyWith(
                  color: _apiKeySet ? AppColors.greenAccent : AppColors.textHint,
                )),
            const Spacer(),
            if (_apiKeySet)
              TextButton(
                onPressed: () async {
                  await _secure.deleteGroqApiKey();
                  setState(() => _apiKeySet = false);
                },
                child: const Text('Remove',
                    style: TextStyle(color: AppColors.redError, fontSize: 12)),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: !_showApiKey,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your DEVA Activation Code...',
              prefixIcon: const Icon(Icons.vpn_key_rounded,
                  color: AppColors.cyanPrimary, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                    _showApiKey
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textHint,
                    size: 18),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveApiKey,
              child: const Text('Activate DEVA'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '🔒 Your Activation Code is encrypted and stored in the Android Keystore. It never leaves your device.',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textHint, fontSize: 11),
          ),
        ]),
      ));

  // ── Voice section ─────────────────────────────────────────────────────
  Widget _voiceSection() => _glassCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _sliderTile('Speech Rate', _speechRate, 0.1, 1.0, (v) async {
            setState(() => _speechRate = v);
            await _prefs.setSpeechRate(v);
            await _voice.reloadSettings();
          }),
          _sliderTile('Voice Pitch', _pitch, 0.5, 2.0, (v) async {
            setState(() => _pitch = v);
            await _prefs.setTtsPitch(v);
            await _voice.reloadSettings();
          }),
          _sliderTile('Volume', _volume, 0.0, 1.0, (v) async {
            setState(() => _volume = v);
            await _prefs.setTtsVolume(v);
            await _voice.reloadSettings();
          }),
          SwitchListTile(
            title: Text('Haptic Feedback',
                style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
            value: _haptic,
            onChanged: (v) async {
              setState(() => _haptic = v);
              await _prefs.setHapticFeedback(v);
            },
          ),
        ]),
      ));

  Widget _sliderTile(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Row(children: [
            Text(label, style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
            const Spacer(),
            Text(value.toStringAsFixed(1),
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.cyanPrimary)),
          ]),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ]);

  // ── Language section ──────────────────────────────────────────────────
  static const _quickLanguages = <String, String>{
    'auto':  '🌐 Auto-detect (Device)',
    'en_US': '🇺🇸 English (US)',
    'en_IN': '🇮🇳 English (India)',
    'hi_IN': '🇮🇳 हिन्दी (Hindi)',
    'ta_IN': '🇮🇳 தமிழ் (Tamil)',
    'te_IN': '🇮🇳 తెలుగు (Telugu)',
    'kn_IN': '🇮🇳 ಕನ್ನಡ (Kannada)',
    'ml_IN': '🇮🇳 മലയാളം (Malayalam)',
    'bn_IN': '🇮🇳 বাংলা (Bengali)',
    'mr_IN': '🇮🇳 मराठी (Marathi)',
    'gu_IN': '🇮🇳 ગુજરાતી (Gujarati)',
    'pa_IN': '🇮🇳 ਪੰਜਾਬੀ (Punjabi)',
    'ur_PK': '🇵🇰 اردو (Urdu)',
    'ar_SA': '🇸🇦 العربية (Arabic)',
    'fr_FR': '🇫🇷 Français (French)',
    'de_DE': '🇩🇪 Deutsch (German)',
    'es_ES': '🇪🇸 Español (Spanish)',
    'ja_JP': '🇯🇵 日本語 (Japanese)',
    'ko_KR': '🇰🇷 한국어 (Korean)',
    'zh_CN': '🇨🇳 中文 (Chinese)',
  };

  String _displayNameForLang(String localeId) =>
      _quickLanguages[localeId] ?? localeId;

  Widget _languageSection() => _glassCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.translate_rounded,
                color: AppColors.cyanPrimary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Voice Language',
                        style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
                    Text(
                      'Language DEVA listens in when you speak',
                      style: AppTypography.bodySmall,
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cyanPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.cyanPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Text(
                _displayNameForLang(_selectedLang),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.cyanPrimary),
              ),
              const Spacer(),
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.cyanPrimary, size: 16),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickLanguages.entries
                .map((e) => _langChip(e.key, e.value))
                .toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.language_rounded, size: 16),
              label: const Text('Browse All Available Languages'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.glassBorder),
              ),
              onPressed: _showAllLanguagesDialog,
            ),
          ),
        ]),
      ));

  Widget _langChip(String localeId, String label) {
    final isSelected = _selectedLang == localeId;
    return GestureDetector(
      onTap: () => _setLanguage(localeId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyanPrimary.withValues(alpha: 0.15)
              : AppColors.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.cyanPrimary : AppColors.glassBorder,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color:
                isSelected ? AppColors.cyanPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _setLanguage(String localeId) async {
    setState(() => _selectedLang = localeId);
    if (localeId == 'auto') {
      await _prefs.setVoiceLanguage('');
    } else {
      await _prefs.setVoiceLanguage(localeId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Voice language set to ${_displayNameForLang(localeId)}'),
          backgroundColor: AppColors.greenAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAllLanguagesDialog() async {
    final locales = await _voice.getAvailableLocales();
    if (!mounted || locales.isEmpty) return;

    locales.sort((a, b) => a.name.compareTo(b.name));

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('All Available Languages',
                style: AppTypography.headingSmall.copyWith(fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: locales.length,
              itemBuilder: (_, i) {
                final locale = locales[i];
                final isSelected = _selectedLang == locale.localeId;
                return ListTile(
                  title: Text(locale.name,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.cyanPrimary
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      )),
                  subtitle:
                      Text(locale.localeId, style: AppTypography.bodySmall),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.cyanPrimary, size: 18)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _setLanguage(locale.localeId);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Permissions section ───────────────────────────────────────────────

  Widget _permissionsSection() => _glassCard(
        Column(children: [
          _permissionTile(
            id: 'overlay',
            icon: _overlayGranted
                ? Icons.layers_rounded
                : Icons.layers_clear_rounded,
            title: 'Floating Avatar Overlay',
            subtitle: _overlayGranted
                ? 'DEVA can appear over other apps when "Hey DEVA" is detected.'
                : 'Grant permission so DEVA can float over other apps.',
            granted: _overlayGranted,
            disclosure: _Disclosure(
              title: 'Floating Avatar Overlay',
              rationale:
                  'DEVA uses the Display Over Other Apps permission to show the floating assistant orb when a wake word is detected in the background. This enables hands-free assistant access while using other apps.',
            ),
            onGrant: () async {
              final granted = await ref
                  .read(assistantProvider.notifier)
                  .requestOverlayPermission();
              if (mounted) setState(() => _overlayGranted = granted);
            },
          ),
          const Divider(height: 0, color: AppColors.glassBorder),
          _permissionTile(
            id: 'notification',
            icon: Icons.notifications_active_rounded,
            title: 'Read Notifications',
            subtitle: 'Allow DEVA to read incoming messages (WhatsApp, SMS) aloud.',
            granted: _notificationGranted,
            disclosure: _Disclosure(
              title: 'Read Notifications',
              rationale:
                  'DEVA uses the Notification Listener permission to read incoming messages aloud in real-time. Notification data is processed locally and never leaves your device.',
            ),
            onGrant: () => _openSettingsPage('openNotificationSettings', 'notification'),
          ),
          const Divider(height: 0, color: AppColors.glassBorder),
          _permissionTile(
            id: 'accessibility',
            icon: Icons.screen_search_desktop_rounded,
            title: 'Screen Awareness',
            subtitle:
                'Allow DEVA to see your screen so you can ask context-aware questions.',
            granted: _accessibilityGranted,
            disclosure: _Disclosure(
              title: 'Screen Awareness',
              rationale:
                  'DEVA uses the Accessibility Service to analyze the text visible on your screen. This allows you to ask context-aware questions. Data is never stored and processed securely.',
            ),
            onGrant: () => _openSettingsPage('openAccessibilitySettings', 'accessibility'),
          ),
          const Divider(height: 0, color: AppColors.glassBorder),
          _permissionTile(
            id: 'usage_access',
            icon: Icons.bar_chart_rounded,
            title: 'Usage Access',
            subtitle: 'Lets DEVA identify the current foreground app for MCP actions.',
            granted: _usageAccessGranted,
            disclosure: _Disclosure(
              title: 'Usage Access',
              rationale:
                  'DEVA uses Usage Access statistics to detect which app is in the foreground, so it can provide context-aware assistance. No usage history is stored or transmitted.',
            ),
            onGrant: () => _openSettingsPage('openUsageAccessSettings', 'usage_access'),
          ),
        ]),
      );

  /// Reusable permission row that shows granted state, a loading spinner
  /// while navigating to settings, and a retry option if still denied on return.
  Widget _permissionTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required _Disclosure disclosure,
    required VoidCallback onGrant,
  }) {
    final isLoading = _navigatingToSettings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon,
              color: granted ? AppColors.greenAccent : AppColors.cyanPrimary,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
                  Text(subtitle, style: AppTypography.bodySmall),
                ]),
          ),
          if (granted)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.greenAccent, size: 20),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    granted
                        ? Icons.check_circle_rounded
                        : Icons.open_in_new_rounded,
                    size: 16,
                  ),
            label: Text(
              isLoading
                  ? 'Opening Settings...'
                  : granted
                      ? '$title Granted'
                      : 'Open Settings',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: granted
                  ? AppColors.greenAccent.withValues(alpha: 0.1)
                  : AppColors.cyanPrimary.withValues(alpha: 0.12),
              foregroundColor:
                  granted ? AppColors.greenAccent : AppColors.cyanPrimary,
              side: BorderSide(
                  color: granted ? AppColors.greenAccent : AppColors.cyanPrimary),
            ),
            onPressed: (granted || isLoading)
                ? null
                : () async {
                    final consent = await _showDisclosureDialog(
                      title: disclosure.title,
                      rationale: disclosure.rationale,
                    );
                    if (!consent) return;
                    onGrant();
                  },
          ),
        ),
      ]),
    );
  }

  // ── Privacy section ───────────────────────────────────────────────────
  Widget _privacySection() => _glassCard(Column(children: [
        _dangerTile(
          icon: Icons.history_rounded,
          title: 'Clear Command History',
          subtitle: 'Delete all locally stored commands',
          onTap: () => _confirmAction(
            'Clear history?',
            () => HistoryDao.instance.clearAll(),
          ),
        ),
        const Divider(height: 0, color: AppColors.glassBorder),
        _dangerTile(
          icon: Icons.psychology_rounded,
          title: 'Clear Memory',
          subtitle: 'Delete all things DEVA remembers',
          onTap: () => _confirmAction(
            'Clear memory?',
            () => MemoryDao.instance.clearAll(),
          ),
        ),
        const Divider(height: 0, color: AppColors.glassBorder),
        _dangerTile(
          icon: Icons.delete_forever_rounded,
          title: 'Delete All Data',
          subtitle: 'Wipe everything: history, memory, activation status',
          isDestructive: true,
          onTap: () => _confirmAction(
              'Delete ALL data? This cannot be undone.', () async {
            await HistoryDao.instance.clearAll();
            await MemoryDao.instance.clearAll();
            await _secure.clearAll();
            if (mounted) setState(() => _apiKeySet = false);
          }),
        ),
        const Divider(height: 0, color: AppColors.glassBorder),
        ListTile(
          leading: const Icon(Icons.policy_rounded,
              color: AppColors.cyanPrimary, size: 20),
          title: const Text('Privacy Policy', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Read our commitment to your privacy'),
          trailing: const Icon(Icons.open_in_new_rounded,
              color: AppColors.textHint, size: 18),
          onTap: () async {
            final uri = Uri.parse(AppConstants.privacyPolicyUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ]));

  Widget _dangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) =>
      ListTile(
        leading: Icon(icon,
            color: isDestructive ? AppColors.redError : AppColors.textSecondary,
            size: 20),
        title: Text(title,
            style: AppTypography.bodyLarge.copyWith(
                fontSize: 14,
                color: isDestructive
                    ? AppColors.redError
                    : AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppTypography.bodySmall),
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textHint, size: 18),
      );

  Future<void> _confirmAction(
      String message, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(message, style: AppTypography.headingSmall),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm',
                  style: TextStyle(color: AppColors.redError))),
        ],
      ),
    );
    if (ok == true) await action();
  }

  Future<bool> _showDisclosureDialog({
    required String title,
    required String rationale,
  }) async {
    final consent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: AppTypography.headingSmall),
        content: Text(rationale, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree & Enable',
                style: TextStyle(color: AppColors.cyanPrimary)),
          ),
        ],
      ),
    );
    return consent == true;
  }

  // ── About section ─────────────────────────────────────────────────────
  Widget _aboutSection() => _glassCard(Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AppColors.cyanPrimary, size: 32),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DEVA', style: AppTypography.headingMedium),
              Text('v${AppConstants.appVersion} · Privacy-first AI assistant',
                  style: AppTypography.bodySmall),
            ]),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: 8),
          Text(
            '🛡 All your data is stored exclusively on your device.\n'
            'No data is sent to any server except voice commands (text only) to OpenRouter AI.',
            style: AppTypography.bodySmall.copyWith(height: 1.7),
            textAlign: TextAlign.center,
          ),
        ]),
      ));
}

/// Holds disclosure dialog content for a permission tile.
class _Disclosure {
  final String title;
  final String rationale;
  const _Disclosure({required this.title, required this.rationale});
}
