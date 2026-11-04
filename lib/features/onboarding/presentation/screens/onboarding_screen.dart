/// Onboarding screen — shown once on first launch.
/// Asks for the Groq API key and microphone permission.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/services/secure_storage_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _secure = SecureStorageService.instance;
  final _apiKeyCtrl = TextEditingController();
  bool _micGranted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _checkMicPermission();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkMicPermission() async {
    final status = await Permission.microphone.status;
    setState(() => _micGranted = status.isGranted);
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    setState(() => _micGranted = status.isGranted);
  }

  Future<void> _finish() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your OpenRouter API key.'),
            backgroundColor: AppColors.redError),
      );
      return;
    }
    if (!_micGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Microphone permission is required.'),
            backgroundColor: AppColors.redError),
      );
      return;
    }
    setState(() => _saving = true);
    await _secure.saveGroqApiKey(key);
    await _secure.markOnboardingComplete();
    if (mounted) context.go(Routes.assistant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      AppColors.cyanPrimary,
                      AppColors.cyanGlow,
                      Color(0xFF001A2A)
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.cyanPrimary.withValues(alpha: 0.4),
                        blurRadius: 30)
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 24),
              Text('Welcome to DEVA', style: AppTypography.headingLarge),
              const SizedBox(height: 8),
              Text('Your privacy-first AI assistant',
                  style: AppTypography.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 40),

              // Step 1: API Key
              _step(
                step: '1',
                title: 'Add your OpenRouter API key',
                description:
                    'Get a key from openrouter.ai\nIt is stored encrypted in your device keystore.',
                child: Column(children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: true,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'sk-or-...',
                      prefixIcon: Icon(Icons.vpn_key_rounded,
                          color: AppColors.cyanPrimary, size: 18),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // Step 2: Microphone permission
              _step(
                step: '2',
                title: 'Allow Microphone',
                description: 'DEVA needs microphone access for voice commands.',
                child: Column(children: [
                  const SizedBox(height: 12),
                  _micGranted
                      ? Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.greenAccent, size: 20),
                          const SizedBox(width: 8),
                          Text('Microphone access granted',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.greenAccent)),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _requestMic,
                            icon: const Icon(Icons.mic_rounded, size: 18),
                            label: const Text('Grant Permission'),
                          ),
                        ),
                ]),
              ),
              const SizedBox(height: 40),

              // Privacy policy link
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(AppConstants.privacyPolicyUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    'By continuing, you agree to our Privacy Policy.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.cyanPrimary,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanPrimary,
                    foregroundColor: AppColors.background,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.background))
                      : Text('Let\'s Go',
                          style:
                              AppTypography.labelLarge.copyWith(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(
          {required String step,
          required String title,
          required String description,
          required Widget child}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanPrimary,
              ),
              child: Center(
                  child: Text(step,
                      style: const TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: AppTypography.headingSmall.copyWith(fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Text(description, style: AppTypography.bodyMedium),
          child,
        ]),
      );
}
