# DEVA — Futuristic AI Assistant 🤖

> Voice-first, privacy-first AI assistant built with Flutter + Kotlin + Groq

## 🛡 Privacy First
- **All data stored locally** on your device (SQLite)
- **API key encrypted** in Android Keystore (hardware-backed AES-256)
- **No analytics, no tracking, no server**
- Only your voice command text is sent to Groq AI — nothing else

---

## ⚡ Quick Start

### Prerequisites
- Flutter 3.19+ (`flutter doctor`)
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API 26+)
- Free Groq API key from [console.groq.com](https://console.groq.com)

### 1. Clone & Install
```bash
cd deva_assistant
flutter pub get
```

### 2. Run
```bash
flutter run
```

On first launch, DEVA will ask for your Groq API key and microphone permission.

---

## 📁 Project Structure

```
lib/
├── core/           # Theme, router, constants
├── features/
│   ├── assistant/  # Avatar, voice loop, AI integration
│   ├── history/    # Local command history (SQLite)
│   ├── settings/   # Voice controls, API key, data management
│   ├── onboarding/ # First-launch setup
│   └── shell/      # Bottom navigation shell
└── shared/
    ├── database/   # SQLite DAOs (history, memory, preferences)
    └── services/   # VoiceService, SecureStorageService
android/
└── .../bridges/    # Kotlin: AppLauncherBridge, SystemActionBridge
```

---

## 🎙 How It Works

```
App Opens
    ↓
DEVA says "Hello sir, how are you doing?"
    ↓
Auto-starts listening (no tap needed)
    ↓
You speak a command
    ↓
Groq AI processes it + optional tool call
    ↓
DEVA speaks the response
    ↓
Auto-listens again (continuous loop)
```

---

## 🛠 Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| UI        | Flutter 3.41+ (Impeller)            |
| State     | Riverpod 2.x                        |
| Voice     | speech_to_text + flutter_tts        |
| AI        | Groq (Llama 3.3 70B) — free tier   |
| Storage   | SQLite (sqflite) — local only       |
| Security  | flutter_secure_storage (Keystore)   |
| Native    | Kotlin MethodChannel                |

---

## 🔐 Security Architecture

```
API Key → Android Keystore (AES-256 hardware-backed)
User Data → SQLite (on-device, never synced)
Network → HTTPS only (network_security_config.xml)
AI calls → Text only, no identity info sent
```

---

## ⚙️ Commands DEVA Understands

| You say...                     | DEVA does...                |
|--------------------------------|-----------------------------|
| "Open YouTube"                 | Launches YouTube            |
| "Search for Flutter tutorials" | Opens Google search         |
| "Set a reminder for 8 AM"      | Opens Android alarm clock   |
| "Remember my favorite color is blue" | Saves to local memory  |
| "Open https://github.com"      | Opens browser               |

---

## 🚀 Roadmap

- **V1 (Current)**: Avatar, voice loop, AI, local storage, tools
- **V2**: Wake word, background listening, floating overlay
- **V3**: On-device AI (Sherpa-ONNX), streaming, multimodal
