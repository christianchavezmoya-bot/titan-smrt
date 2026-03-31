# Titan SMRT - Flutter Mobile App

Production-ready Flutter fitness tracking application with AI-powered coaching.

## Features

### Core Functionality
- **Smart Workout Logging**: Quick set tracking with 3-click UX
- **Offline-First**: Local SQLite database with sync capability
- **AI-Powered Insights**: Form analysis, progression tracking, plateau detection
- **Exercise Library**: Custom exercises with media support
- **Routine Management**: Create and manage workout templates
- **Nutrition Tracking**: Daily macro logging
- **Analytics Dashboard**: Heatmaps, PR tracking, performance metrics
- **Hardware Integration**: Apple Watch, Garmin BLE support (Pro)
- **Social Features**: Share workouts, compete with friends (Pro)

### User Experience
- Dark theme with modern UI
- Haptic feedback throughout
- Staggered animations for smooth transitions
- Smart timers with audio cues
- Conflict resolution for sync issues
- Comprehensive error handling

## Getting Started

### Prerequisites

- Flutter SDK 3.19.0 or higher
- Dart 3.0.0 or higher
- Android Studio / Xcode
- Android SDK 21+ / iOS 12+
- Backend API running (see fastapi_service/README.md)

### Installation

```bash
# Clone repository
git clone <your-repo-url>
cd titan-smrt/flutter_app

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root app widget
├── theme.dart                # App theme configuration
├── navigation/
│   └── app_scaffold.dart   # Main navigation scaffold
├── screens/
│   ├── hub_screen.dart         # Home/workout screen
│   ├── analytics_screen.dart   # Analytics dashboard
│   ├── exercises_screen.dart   # Exercise & routine library
│   ├── nutrition_screen.dart   # Nutrition tracking
│   ├── profile_screen.dart    # User profile & settings
│   ├── auth_screen.dart       # Login/register
│   ├── onboarding_screen.dart # First-time setup
│   └── subscription_screen.dart # Pro features & pricing
├── widgets/
│   ├── active_workout_card.dart # Workout card with timer
│   └── staggered_fade_in.dart   # Animation widget
└── services/
    ├── local_store.dart       # SQLite database
    ├── api_client.dart        # HTTP client
    ├── auth_service.dart       # Authentication
    ├── workout_service.dart    # Workout logic
    ├── sync_service.dart       # Sync with server
    ├── error_handler.dart     # Error management
    └── [other services...]
```

## Configuration

### Environment Setup

Edit [`lib/main.dart`](lib/main.dart:15) to configure API endpoint:

```dart
final authController = AuthController(
  AuthService('https://your-api-domain.com')
);
```

### Theme Customization

Modify [`lib/theme.dart`](lib/theme.dart:1) to customize colors and styling.

### Feature Flags

Enable/disable features in [`lib/app.dart`](lib/app.dart:1).

## Development

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate coverage report
genhtml coverage/lcov.info -o coverage/html
```

### Code Quality

```bash
# Format code
flutter format .

# Analyze code
flutter analyze

# Fix issues
dart fix --apply
```

### Hot Reload

The app supports hot reload during development. Make changes and press `r` in the terminal.

## Building for Production

### Android

```bash
# Configure signing (see android/app/build.gradle)
flutter build apk --release

# Or build App Bundle for Play Store
flutter build appbundle --release
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
# Configure signing in Xcode
flutter build ios --release

# Open in Xcode for final build
open ios/Runner.xcworkspace
```

**Output**: `build/ios/iphoneos/Runner.app`

## Testing

### Manual Testing Checklist

- [ ] All screens load without errors
- [ ] Navigation works between all tabs
- [ ] Offline mode functions correctly
- [ ] Sync resolves conflicts properly
- [ ] Authentication flow works end-to-end
- [ ] Workouts can be created and logged
- [ ] Exercises and routines can be managed
- [ ] Nutrition tracking saves data
- [ ] Analytics display correctly
- [ ] Settings persist across app restarts
- [ ] Error messages are user-friendly
- [ ] Haptic feedback works throughout

### Device Testing

Test on minimum required devices:
- **Android**: API 21 (Android 5.0) - latest
- **iOS**: iOS 12.0 - latest

### Performance Testing

- App startup time < 3 seconds
- Screen transitions < 100ms
- Database queries < 50ms
- API responses < 500ms

## Deployment

### Google Play Store

1. **Prepare Assets**:
   - App icon: 512x512 PNG
   - Feature graphic: 1024x500 PNG
   - Screenshots: Phone and tablet sizes

2. **Configure Listing**:
   - Title: Titan SMRT
   - Short description: Smart fitness tracking
   - Full description: [Use marketing copy]
   - Category: Health & Fitness
   - Content rating: Everyone

3. **Upload**:
   - APK or AAB file
   - Privacy policy URL
   - Content rating questionnaire

### Apple App Store

1. **Prepare Assets**:
   - App icon: 1024x1024 PNG
   - Screenshots: All iPhone/iPad sizes
   - App preview: 15-30 second video

2. **Configure Listing**:
   - App name: Titan SMRT
   - Description: Smart fitness tracking
   - Keywords: fitness, workout, tracking, AI
   - Category: Health & Fitness
   - Age rating: 4+

3. **Upload**:
   - Through Xcode or App Store Connect
   - Privacy policy URL
   - Export compliance documentation

## Troubleshooting

### Common Issues

**App won't build**:
```bash
flutter clean
flutter pub get
flutter doctor
```

**Sync conflicts**:
- Check network connection
- Review conflict resolution screen
- Force sync from settings

**Database errors**:
- Clear app data from settings
- Reinstall app if persistent

**Performance issues**:
- Close background apps
- Restart device
- Check available storage

## Dependencies

Key dependencies:
- `flutter`: UI framework
- `provider`: State management
- `sqflite`: Local database
- `http`/`dio`: API client
- `fl_chart`: Analytics charts
- `health`: Health data integration
- `camera`: Form video capture

See [`pubspec.yaml`](pubspec.yaml:1) for complete list.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `flutter test`
5. Submit a pull request

## License

[Your License Here]

## Support

- **Documentation**: See project wiki
- **Issues**: GitHub Issues
- **Email**: support@titanapp.com

---

*Built with Flutter*  
*Version: 1.0.0*
