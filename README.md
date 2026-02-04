# AI Quick Chat - Apple Watch App

Standalone Apple Watch app for AI Quick Chat AAC (Augmentative and Alternative Communication), enabling people with speech difficulties to communicate independently using cellular connectivity.

## Requirements

- watchOS 10.0+
- Apple Watch Series 3+ (GPS + Cellular recommended)
- Xcode 15.0+

## Features

- **Phrase Grid**: 2-column scrollable grid with 8 customizable phrases
- **Text-to-Speech**: Hybrid TTS with Gemini API (primary) and AVSpeechSynthesizer (offline fallback)
- **AI Context Packs**: Generate context-aware phrases using Gemini 2.5 Flash
- **Offline Support**: Local-first data with SwiftData, automatic sync when online
- **Cellular Ready**: Works independently on Apple Watch with cellular connectivity
- **Secure Auth**: JWT token storage in Keychain

## Project Structure

```
AIQuickChatWatch/
├── AIQuickChatWatchApp.swift        # App entry point with SwiftData
├── Models/
│   ├── SyncStatus.swift             # Sync state enum
│   ├── Phrase.swift                 # SwiftData phrase model
│   ├── UserSettings.swift           # Settings model
│   ├── UsageLog.swift               # Analytics model
│   └── APIModels.swift              # DTOs for API communication
├── Services/
│   ├── KeychainService.swift        # Secure token storage
│   ├── ReachabilityService.swift    # Network monitoring
│   ├── APIClient.swift              # HTTP client with JWT auth
│   ├── GeminiService.swift          # Gemini API for TTS & AI
│   ├── TTSService.swift             # Text-to-Speech manager
│   └── SyncService.swift            # Offline/online sync
├── ViewModels/
│   ├── AuthViewModel.swift          # Authentication state
│   └── PhraseGridViewModel.swift    # Main phrase grid logic
├── Views/
│   ├── ContentView.swift            # Root navigation
│   ├── Components/
│   │   ├── OfflineBanner.swift      # Offline indicator
│   │   └── TypeMessageView.swift    # Custom text input
│   ├── PhraseGrid/
│   │   ├── PhraseGridView.swift     # Main phrase interface
│   │   ├── PhraseButtonView.swift   # Individual phrase button
│   │   └── TTSStatusView.swift      # TTS status indicator
│   ├── Auth/
│   │   └── LoginView.swift          # Login/signup screen
│   └── Settings/
│       ├── SettingsView.swift       # Settings hub
│       ├── LanguagePickerView.swift # Language selection
│       └── ResponseModeView.swift   # Environment selection
└── Utilities/
    ├── AudioConverter.swift         # PCM to WAV conversion
    └── HapticManager.swift          # Haptic feedback
```

## Setup

1. Open `AIQuickChatWatch.xcodeproj` in Xcode
2. Set your Development Team in Signing & Capabilities
3. Configure environment variables:
   - `API_URL`: Backend API URL (defaults to `https://api.aiquickchat.com`)
   - `GEMINI_API_KEY`: Google Gemini API key

### API Key Configuration

You can set the Gemini API key in one of two ways:

1. **Environment Variable**: Set `GEMINI_API_KEY` in your scheme's environment variables
2. **Keychain**: The app can store the API key securely in Keychain

## Architecture

### Data Flow

1. **Local First**: All CRUD operations happen locally with SwiftData
2. **Sync Status**: Each entity tracks its sync state (synced, pendingUpload, pendingUpdate, pendingDelete)
3. **Background Sync**: Automatic sync when network becomes available
4. **Conflict Resolution**: Server wins for simplicity

### TTS Pipeline

1. Check network connectivity
2. If online: Request speech from Gemini TTS API
3. Receive base64 PCM audio (16-bit, 24kHz)
4. Convert to WAV format with proper headers
5. Play via AVAudioPlayer
6. If offline/error: Fall back to AVSpeechSynthesizer

## API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /api/auth/login | Login |
| POST | /api/auth/signup | Registration |
| GET | /api/phrases | Fetch phrases |
| POST | /api/phrases | Create phrase |
| PUT | /api/phrases/:id | Update phrase |
| DELETE | /api/phrases/:id | Delete phrase |
| GET/PUT | /api/settings | Settings sync |
| POST | /api/analytics/log | Event logging |

## Testing

1. **Simulator**: Run on watchOS Simulator in Xcode
2. **Offline Test**: Enable airplane mode, verify local TTS works
3. **Sync Test**: Create phrase offline → go online → verify sync
4. **Physical Device**: Deploy to Apple Watch with cellular for full testing

## License

Proprietary - AI Quick Chat
