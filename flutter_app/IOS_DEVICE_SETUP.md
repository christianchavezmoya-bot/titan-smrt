# Running Titan on Your iPhone

## Prerequisites

1. **Apple Developer Account** (Free or Paid)
   - Free: Can run apps for 7 days before needing to re-sign
   - Paid ($99/year): Can distribute to TestFlight and App Store

2. **Xcode** (latest version from App Store)

3. **Flutter** installed and configured

---

## Step-by-Step Setup

### Step 1: Prepare Your iPhone

1. Connect your iPhone to your Mac via USB cable
2. Unlock your iPhone and tap "Trust" when prompted
3. On your iPhone, go to:
   - **Settings → Privacy & Security → Developer Mode** → Turn ON
   - Restart your iPhone when prompted

### Step 2: Configure Apple ID in Xcode

1. Open Xcode
2. Go to **Xcode → Settings (or Preferences) → Accounts**
3. Click **+** and sign in with your Apple ID
4. Select your team (your personal team for free account)

### Step 3: Configure the Project

```bash
# Navigate to the Flutter app
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/flutter_app

# Open iOS project in Xcode
open ios/Runner.xcworkspace
```

### Step 4: Set Signing in Xcode

1. In Xcode, select **Runner** project in the left sidebar
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** from the dropdown (your Apple ID)
6. Xcode will automatically generate a provisioning profile

### Step 5: Update Bundle Identifier (if needed)

If you get a bundle identifier conflict:
1. In Xcode, under **Signing & Capabilities**
2. Change **Bundle Identifier** to something unique, e.g.:
   - `com.yourname.titan` instead of `com.example.titan`

### Step 6: Run on iPhone

```bash
# In terminal, check available devices
flutter devices

# You should see your iPhone listed, e.g.:
# iPhone (mobile) • 00008030-001234567890ABC • ios • iOS 17.0

# Run on your iPhone
flutter run -d <your-device-id>

# Or simply run (will prompt to select device)
flutter run
```

---

## Troubleshooting

### "Developer Mode Required"
- Go to **Settings → Privacy & Security → Developer Mode** on iPhone
- Turn it ON and restart

### "Untrusted Developer"
- Go to **Settings → General → VPN & Device Management**
- Tap your Apple ID under "Developer App"
- Tap **Trust**

### "No matching provisioning profiles"
1. Open Xcode
2. **Product → Clean Build Folder** (Cmd+Shift+K)
3. Re-select your team in Signing & Capabilities
4. Try again

### "Bundle identifier not unique"
- Change the bundle identifier in Xcode to something unique like `com.yourname.titan`

### "Could not launch app"
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Device not showing up
```bash
# Check Flutter doctor
flutter doctor -v

# Restart device detection
flutter devices --reset
```

---

## Quick Commands

```bash
# Navigate to project
cd /Users/christianchavez/Documents/IOS\ Developer/Titan/titan-smrt/flutter_app

# Check devices
flutter devices

# Run on iPhone
flutter run -d <device-id>

# Or run with verbose output
flutter run -d <device-id> -v
```

---

## Using VS Code

1. Open the `flutter_app` folder in VS Code
2. Install the Flutter extension if not already installed
3. Connect your iPhone
4. Click the device selector in the bottom-right status bar
5. Select your iPhone
6. Press F5 or click **Run → Start Debugging**

---

## Hot Reload on Device

Once running:
- Save any code changes → App hot reloads automatically
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## Next Steps

- To share with testers: Use **TestFlight** (requires paid Apple Developer account)
- To submit to App Store: Follow the **APP_STORE_SUBMISSION.md** guide