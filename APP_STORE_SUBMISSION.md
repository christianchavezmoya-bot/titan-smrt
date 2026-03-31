# Titan SMRT - App Store Submission Guide

Complete guide for submitting Titan SMRT to Google Play Store and Apple App Store.

## Table of Contents

1. [Pre-Submission Checklist](#pre-submission-checklist)
2. [Google Play Store](#google-play-store)
3. [Apple App Store](#apple-app-store)
4. [Required Assets](#required-assets)
5. [App Store Descriptions](#app-store-descriptions)
6. [Privacy Policy](#privacy-policy)
7. [Testing Guidelines](#testing-guidelines)
8. [Post-Submission](#post-submission)

---

## Pre-Submission Checklist

### Technical Requirements

- [ ] App compiles without errors or warnings
- [ ] All screens load and function correctly
- [ ] No debug code or test data remains
- [ ] App works offline when expected
- [ ] Sync functionality tested thoroughly
- [ ] Error handling is user-friendly
- [ ] No hardcoded API keys or secrets
- [ ] Code signing configured correctly
- [ ] ProGuard/R8 obfuscation enabled (Android)
- [ ] App Transport Security enabled (iOS)
- [ ] Minimum SDK versions met (Android 21+, iOS 12+)
- [ ] Target SDK versions current
- [ ] Permissions documented and justified

### Content Requirements

- [ ] App name is unique and not trademarked
- [ ] Short description is compelling and clear
- [ ] Full description is comprehensive and accurate
- [ ] Screenshots provided for all required sizes
- [ ] App icon meets specifications
- [ ] Feature graphic provided (Google Play)
- [ ] Privacy policy URL is accessible
- [ ] Content rating questionnaire completed
- [ ] Category selected correctly (Health & Fitness)
- [ ] Keywords researched and optimized
- [ ] Support email configured

### Legal Requirements

- [ ] Privacy policy published
- [ ] Terms of service published (if applicable)
- [ ] Data collection documented
- [ ] Third-party services disclosed
- [ ] Export compliance documentation ready
- [ ] COPPA compliance (if targeting children)

---

## Google Play Store

### Account Setup

1. **Create Developer Account**
   - Go to [Google Play Console](https://play.google.com/console)
   - Pay $25 one-time registration fee
   - Complete account setup

2. **Create Application**
   - Console → All apps → Create app
   - Enter app name: "Titan SMRT"
   - Select language: English (US)

### Store Listing

#### App Information

```
App Name: Titan SMRT
Short Description: Smart fitness tracking with AI-powered coaching
Full Description: [See App Store Descriptions section]
Category: Health & Fitness
Content Rating: Everyone
```

#### Contact Details

```
Website: https://titanapp.com
Email: support@titanapp.com
Phone: (Optional - your support number)
Privacy Policy URL: https://titanapp.com/privacy
```

### Graphic Assets

#### App Icon

- **Required**: 512x512 PNG
- **Format**: PNG with transparency
- **Design**: Clean, fitness-themed
- **File size**: < 1MB

#### Feature Graphic

- **Required**: 1024x500 PNG
- **Format**: PNG
- **Purpose**: Featured in store listings
- **Safe zone**: Center 75% of image

#### Screenshots

**Phone Screenshots (Required)**:
- At least 2 screenshots
- Minimum 2, maximum 8
- **Sizes**: 
  - Phone: 320px, 480px, 720px, 1080px, 1440px
  - 7" tablet: 800px, 1200px
  - 10" tablet: 1200px, 1600px
- **Format**: PNG or JPEG
- **Content**: Show key features

**Required Screenshots to Include**:
1. Hub screen with active workout
2. Analytics dashboard with heatmap
3. Exercise library view
4. Workout logging interface
5. Subscription/Pro features screen
6. Nutrition tracking interface

### Content Rating

Complete the content rating questionnaire:

```
Violence: None
Sexual Content: None
Profanity: None
Drug Reference: None
Controlled Substances: None
```

### Pricing & Distribution

```
Free with In-App Purchases:
- Free tier: Basic features
- Pro tier: $9.99/month
- Trial: 7-day free trial, no credit card required
```

### Submission Process

1. **Upload APK/AAB**
   - Build: `flutter build appbundle --release`
   - Upload: `build/app/outputs/bundle/release/app-release.aab`

2. **Complete Store Listing**
   - Fill all required fields
   - Upload all assets
   - Review and submit

3. **Review Process**
   - Google review: 1-3 days
   - Prepare for potential rejection reasons
   - Have update plan ready

4. **Launch**
   - Once approved, app goes live
   - Monitor initial downloads and reviews
   - Respond to user feedback quickly

---

## Apple App Store

### Account Setup

1. **Create Developer Account**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Pay $99/year membership fee
   - Complete enrollment and tax forms

2. **Create App Record**
   - My Apps → + → New App
   - Platform: iOS
   - Name: Titan SMRT
   - Bundle ID: com.yourcompany.titan
   - SKU: TITAN_SMRT

### App Information

#### Basic Information

```
Name: Titan SMRT
Primary Language: English (U.S.)
Secondary Language: (Optional)
Bundle ID: com.yourcompany.titan
SKU: TITAN_SMRT
Category: Health & Fitness
Age Rating: 4+
```

#### Pricing and Availability

```
Price: Free with In-App Purchases
Availability: All countries (or select specific)
Date: Schedule your release date
```

### App Store Assets

#### App Icon

- **Required**: 1024x1024 PNG
- **Format**: PNG without alpha channel
- **Design**: iOS-style, rounded corners
- **File size**: < 1MB

#### Screenshots

**iPhone Screenshots (Required)**:
- 6.5" display: 1290x2796 @3x
- 5.5" display: 1242x2688 @3x
- Required for each supported iOS version

**iPad Screenshots (Required)**:
- 12.9" display: 2048x2732 @2x
- 11" display: 2048x1536 @2x

**Screenshots to Include**:
1. Hub screen with workout card
2. Analytics with insights
3. Exercise library
4. Subscription screen
5. Profile settings
6. Nutrition tracking

### App Information

#### Description

Use the full description from [App Store Descriptions](#app-store-descriptions) section.

#### Keywords

```
fitness, workout, tracking, gym, exercise, training,
AI coaching, smart fitness, personal trainer, workout log,
nutrition, macros, health, fitness app, workout tracker
```

#### Support URL

```
https://titanapp.com/support
```

#### Marketing URL

```
https://titanapp.com
```

#### Privacy Policy URL

```
https://titanapp.com/privacy
```

### Build and Upload

1. **Configure Signing**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Project > Signing & Capabilities
   - Select your team and signing certificate

2. **Build Archive**
   ```bash
   flutter build ios --release
   ```
   - Open Xcode: Product > Archive
   - Distribute App

3. **Upload to App Store Connect**
   - Upload from Xcode or Transporter
   - Complete app information
   - Submit for review

### Review Process

- **Apple review**: 1-3 days typically
- **Rejection reasons**: Review guidelines carefully
- **Update process**: Faster than initial submission
- **Respond to feedback**: Use TestFlight for beta testing

---

## Required Assets

### Icon Specifications

#### Google Play
```
High-res icon: 512x512 PNG
Adaptive icon: 512x512 PNG with safe zone
Foreground: 512x512 PNG
Background: 512x512 PNG
```

#### Apple App Store
```
App icon: 1024x1024 PNG
No alpha channel
iOS-style design
```

### Screenshot Requirements

#### Google Play
```
Phone: 320, 480, 720, 1080, 1440px wide
7" tablet: 800, 1200px wide
10" tablet: 1200, 1600px wide
Format: PNG or JPEG
Max size: 8MB per screenshot
```

#### Apple App Store
```
iPhone 6.5": 1290x2796 @3x
iPhone 5.5": 1242x2688 @3x
iPad 12.9": 2048x2732 @2x
iPad 11": 2048x1536 @2x
Format: PNG or JPEG
Max size: 500MB total
```

### Feature Graphic (Google Play Only)

```
Size: 1024x500 PNG
Format: PNG or JPEG
Max size: 8MB
Safe zone: Center 75% of image
```

---

## App Store Descriptions

### Short Description (80 characters)

```
Smart fitness tracking with AI-powered coaching and personalized insights.
```

### Full Description (4000 characters)

```
Titan SMRT is your intelligent fitness companion that transforms how you track workouts and achieve your goals. Powered by advanced AI, Titan provides personalized coaching, form analysis, and progression insights to help you train smarter, not harder.

KEY FEATURES:

🏋 SMART WORKOUT LOGGING
• 3-click workout logging for seamless tracking
• Automatic rest timers with haptic feedback
• Personal record detection and celebration
• Quick set logging with weight, reps, and RPE

🤖 AI-POWERED COACHING
• Real-time form analysis through video upload
• Plateau detection with actionable suggestions
• Progression tracking using 1RM calculations
• Personalized workout recommendations

📊 ADVANCED ANALYTICS
• Muscle group heatmaps for balanced training
• PR leaderboard to track your progress
• Volume and intensity trends over time
• Performance metrics and insights

📚 COMPREHENSIVE LIBRARY
• 500+ exercises with video demonstrations
• Create custom routines and templates
• Filter by muscle group and equipment
• Save your favorite exercises

🍎 NUTRITION TRACKING
• Daily macro logging (protein, carbs, fats)
• Calorie tracking for goal alignment
• Nutrition impact on workout performance
• Meal planning suggestions

⚡ OFFLINE-FIRST DESIGN
• Full functionality without internet
• Automatic sync when connection available
• Conflict resolution for data integrity
• Local SQLite database for speed

💎 PRO FEATURES (Subscription)
• Apple Watch and Garmin integration
• Advanced AI insights and analysis
• Hardware heart rate monitoring
• Priority support and faster updates
• Remove ads and unlock all features

Whether you're a beginner starting your fitness journey or an experienced athlete looking to optimize your training, Titan SMRT adapts to your level and helps you achieve your goals faster.

Download Titan SMRT today and start training with intelligence!
```

### Keywords (Google Play - 100 characters)

```
fitness, workout, gym, exercise, training, AI coaching,
smart fitness, personal trainer, workout log, nutrition, macros,
health, fitness app, workout tracker, strength training
```

### Keywords (Apple App Store - 100 characters)

```
fitness, workout, gym, exercise, training, AI coaching,
smart fitness, personal trainer, workout log, nutrition, macros,
health, fitness app, workout tracker, strength training
```

---

## Privacy Policy

### Required Sections

Your privacy policy must include:

1. **Data Collection**
   - What data is collected (workouts, exercises, profile)
   - How it's collected (user input, device sensors)
   - Why it's collected (to provide features)

2. **Data Usage**
   - How data is used (tracking, analysis, personalization)
   - AI processing (form analysis, recommendations)
   - Third-party sharing (none without consent)

3. **Data Storage**
   - Local storage (SQLite on device)
   - Cloud storage (PostgreSQL on secure servers)
   - Encryption methods

4. **Data Sharing**
   - What is shared (nothing by default)
   - Optional sharing (social features)
   - Third-party access (only with explicit consent)

5. **User Rights**
   - Access to collected data
   - Right to delete data
   - Right to export data
   - Right to opt out of analytics

6. **Contact Information**
   - Privacy questions email
   - Company contact details
   - Data protection officer

### Privacy Policy Template

See [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) for a complete template.

---

## Testing Guidelines

### Pre-Submission Testing

#### Functional Testing

- [ ] All screens load without crashes
- [ ] Navigation works between all tabs
- [ ] Buttons and gestures respond correctly
- [ ] Forms validate input properly
- [ ] Error messages display appropriately
- [ ] Offline mode functions correctly
- [ ] Sync works in both directions
- [ ] Push notifications (if implemented)

#### Device Testing

**Android**:
- [ ] Test on minimum SDK (API 21)
- [ ] Test on current SDK (latest)
- [ ] Test on different screen sizes
- [ ] Test on different Android versions
- [ ] Test with different network conditions

**iOS**:
- [ ] Test on minimum iOS version (12.0)
- [ ] Test on current iOS version
- [ ] Test on different iPhone models
- [ ] Test on iPad (if supported)
- [ ] Test with different network conditions

#### Performance Testing

- [ ] App startup < 3 seconds
- [ ] Screen transitions < 100ms
- [ ] Database queries < 50ms
- [ ] API responses < 500ms
- [ ] Memory usage acceptable
- [ ] Battery usage reasonable

#### Edge Cases

- [ ] No internet connection
- [ ] Server errors
- [ ] Database corruption
- [ ] Low storage space
- [ ] Background app termination
- [ ] Multiple rapid requests

### Beta Testing

#### Google Play

1. **Create Internal Test Track**
   - Upload APK to internal testing
   - Test with up to 100 accounts

2. **Create Closed Beta**
   - Select testers from email list
   - Collect feedback and fix issues

3. **Create Open Beta**
   - Opt-in link for public testing
   - Wider audience for feedback

#### Apple App Store

1. **TestFlight**
   - Upload build to TestFlight
   - Invite up to 10,000 testers
   - Create groups for different testing phases

2. **Internal Testing**
   - Test with development team
   - Use TestFlight builds

---

## Post-Submission

### Monitoring

- **Downloads**: Track daily and weekly
- **Ratings & Reviews**: Monitor and respond
- **Crash Reports**: Fix critical issues immediately
- **Performance**: Monitor app store performance

### Updates

- **Bug Fixes**: Quick turnaround for critical issues
- **Feature Updates**: Regular cadence (monthly)
- **Performance**: Optimize based on metrics
- **Compatibility**: Test on new OS versions

### Marketing

- **App Store Optimization (ASO)**:
  - Update keywords based on search data
  - Optimize screenshots for conversion
  - A/B test descriptions
  - Monitor competitor rankings

- **User Acquisition**:
  - Social media promotion
  - Fitness community engagement
  - Influencer partnerships
  - App review requests

### Support

- **Response Time**: < 24 hours for critical issues
- **FAQ**: Maintain comprehensive FAQ
- **Help Documentation**: Keep updated
- **Contact Channels**: Multiple options (email, in-app)

---

## Common Rejection Reasons

### Google Play

1. **Policy Violations**
   - Misleading app name
   - Inappropriate content
   - Copyright infringement
   - Solution: Review policies carefully

2. **Technical Issues**
   - App crashes
   - Poor performance
   - Solution: Thorough testing before submission

3. **Metadata Issues**
   - Missing screenshots
   - Poor description
   - Solution: Complete all required fields

### Apple App Store

1. **Guideline Violations**
   - Not following Human Interface Guidelines
   - Inappropriate content
   - Solution: Study HIG thoroughly

2. **Technical Issues**
   - App crashes on launch
   - Poor performance
   - Solution: Test on multiple devices

3. **Metadata Issues**
   - Missing required information
   - Inaccurate screenshots
   - Solution: Double-check all fields

---

## Timeline

### Recommended Submission Schedule

**Week 1-2**: Final testing and bug fixes
**Week 3**: Prepare assets and metadata
**Week 4**: Submit to both stores
**Week 5-7**: Review period (1-3 days typical)
**Week 8**: Launch and marketing

### Launch Checklist

- [ ] All testing completed
- [ ] Assets prepared and optimized
- [ ] Metadata written and reviewed
- [ ] Privacy policy published
- [ ] Support channels ready
- [ ] Marketing materials prepared
- [ ] Response plan for reviews
- [ ] Update plan ready

---

## Resources

### Official Documentation

- [Google Play Console](https://play.google.com/console)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Google Play Policy Center](https://play.google.com/about/developer-content-policy)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Tools

- **Screenshots**: Use device emulators
- **Icons**: Figma or similar design tools
- **Metadata**: ASO tools for keyword research
- **Analytics**: Store analytics dashboards

---

## Contact

For submission questions or issues:
- **Email**: support@titanapp.com
- **Documentation**: See project README
- **Issues**: GitHub Issues

---

*Last Updated: 2024-01-01*
*Version: 1.0.0*
