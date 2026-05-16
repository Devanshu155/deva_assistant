/// Settings screen — voice preferences, API key, data management.
/// All data stays local. API key stored in Android Keystore.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../../shared/services/secure_storage_service.dart';
import '../../../../shared/database/preferences_dao.dart';
import '../../../../shared/database/history_dao.dart';
import '../../../../shared/database/memory_dao.dart';
import '../../../../shared/services/voice_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _prefs   = PreferencesDao.instance;
  final _secure  = SecureStorageService.instance;
  final _voice   = VoiceService.instance;

  final _apiKeyCtrl = TextEditingController();

  double _speechRate = AppConstants.defaultSpeechRate;
  double _pitch      = AppConstants.defaultTtsPitch;
  double _volume     = AppConstants.defaultTtsVolume;
  bool   _haptic     = true;
  bool   _apiKeySet  = false;
  bool   _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final rate   = await _prefs.getSpeechRate();
    final pitch  = await _prefs.getTtsPitch();
    final vol    = await _prefs.getTtsVolume();
    final haptic = await _prefs.getHapticFeedback();
    final hasKey = await _secure.hasGroqApiKey();
    setState(() {
      _speechRate = rate;
      _pitch      = pitch;
      _volume     = vol;
      _haptic     = haptic;
      _apiKeySet  = hasKey;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Settings', style: AppTypography.headingSmall.copyWith(letterSpacing: 2)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _sectionHeader('AI API KEY'),
          _apiKeySection(),
          const SizedBox(height: 20),
          _sectionHeader('VOICE'),
          _voiceSection(),
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

  // ── Section header ───────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
    child: Text(title, style: AppTypography.neonLabel.copyWith(fontSize: 11, letterSpacing: 3)),
  );

  // ── Glassmorphism card wrapper ───────────────────────────────────────
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

  // ── API Key section ──────────────────────────────────────────────────
  Widget _apiKeySection() => _glassCard(Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(_apiKeySet ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: _apiKeySet ? AppColors.greenAccent : AppColors.textHint, size: 18),
        const SizedBox(width: 8),
        Text(_apiKeySet ? 'API key stored securely' : 'No API key set',
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
            child: const Text('Remove', style: TextStyle(color: AppColors.redError, fontSize: 12)),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _apiKeyCtrl,
        obscureText: !_showApiKey,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Paste your Groq API key here...',
          prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.cyanPrimary, size: 18),
          suffixIcon: IconButton(
            icon: Icon(_showApiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textHint, size: 18),
            onPressed: () => setState(() => _showApiKey = !_showApiKey),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveApiKey,
          child: const Text('Save API Key'),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '🔒 Your API key is encrypted and stored in the Android Keystore. It never leaves your device.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textHint, fontSize: 11),
      ),
    ]),
  ));

  // ── Voice section ────────────────────────────────────────────────────
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
        title: Text('Haptic Feedback', style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
        value: _haptic,
        onChanged: (v) async {
          setState(() => _haptic = v);
          await _prefs.setHapticFeedback(v);
        },
      ),
    ]),
  ));

  Widget _sliderTile(String label, double value, double min, double max, ValueChanged<double> onChanged) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 4),
        child: Row(children: [
          Text(label, style: AppTypography.bodyLarge.copyWith(fontSize: 14)),
          const Spacer(),
          Text(value.toStringAsFixed(1), style: AppTypography.labelMedium.copyWith(color: AppColors.cyanPrimary)),
        ]),
      ),
      Slider(value: value, min: min, max: max, onChanged: onChanged),
    ]);

  // ── Privacy section ──────────────────────────────────────────────────
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
      subtitle: 'Wipe everything: history, memory, API key',
      isDestructive: true,
      onTap: () => _confirmAction('Delete ALL data? This cannot be undone.', () async {
        await HistoryDao.instance.clearAll();
        await MemoryDao.instance.clearAll();
        await _secure.clearAll();
        setState(() => _apiKeySet = false);
      }),
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
      leading: Icon(icon, color: isDestructive ? AppColors.redError : AppColors.textSecondary, size: 20),
      title: Text(title, style: AppTypography.bodyLarge.copyWith(
          fontSize: 14, color: isDestructive ? AppColors.redError : AppColors.textPrimary)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
    );

  Future<void> _confirmAction(String message, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(message, style: AppTypography.headingSmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: AppColors.redError))),
        ],
      ),
    );
    if (ok == true) await action();
  }

  // ── About section ─────────────────────────────────────────────────────
  Widget _aboutSection() => _glassCard(Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.cyanPrimary, size: 32),
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
        'No data is sent to any server except voice commands (text only) to Groq AI.',
        style: AppTypography.bodySmall.copyWith(height: 1.7),
        textAlign: TextAlign.center,
      ),
    ]),
  ));
}
