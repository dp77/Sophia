# Changelog

## 2026-10-19

### Authentication and navigation

- Replaced the login screen with the supplied authentication UI.
- Added the supplied registration screen and shared authentication widgets.
- Added the Google sign-in SVG asset at `assets/svg/google.svg`.
- Made the Settings profile card open `LoginScreen` for guests and `AboutYouScreen` for authenticated users.

### Analytics

- Added centralized analytics in `lib/data/analytics/analytics_service.dart`.
- Added screen and inner-screen naming for the main app surfaces, including names such as `HomeScreen` and `HomeTab`.
- Added analytics coverage for onboarding, authentication, settings, watch-and-earn, premium, chat, image, and generation flows.

### Ads and monetization

- Added rewarded-ad behavior to the Watch & Earn reward ticket.
- Updated Watch & Earn credit handling to refresh the authoritative profile after a successful reward, so credits update immediately.
- Added splash interstitial ads with Remote Config switches:
  - Android: `ShowSplashInterstitialAd`
  - iOS: `IosShowSplashInterstitialAd`
- Added splash interstitial production units:
  - Android: `ca-app-pub-7809814089977162/3224098475`
  - iOS: `ca-app-pub-7809814089977162/2370181804`
- Added app-resume App Open ads with existing Remote Config switches:
  - Android: `showAppOpen`
  - iOS: `iosShowAppOpen`
- Added app-resume production units:
  - Android: `ca-app-pub-7809814089977162/8219642735`
  - iOS: `ca-app-pub-7809814089977162/9003450832`
- Added cooldown protection so an App Open ad does not appear immediately after another full-screen ad.
- Corrected debug App Open test units for Android and iOS.

### Onboarding and assets

- Replaced `assets/images/onboard1.png`, `onboard2.png`, and `onboard3.png` with the supplied photos.
- Preserved the original asset paths so onboarding, authentication, premium, and promotional surfaces continue using the same references.
- Added clamping scroll physics to login and registration screens.
- Added clamping scroll physics to the girlfriend grid.
- Removed the visible `RefreshIndicator` from the loaded girlfriend grid; initial skeleton and failed-load retry states remain.

### UI fixes

- Fixed the Settings Watch & Earn card callback and missing `WatchEarnScreen` imports.
- Fixed the non-constant `Colors.white.withValues(...)` icon declaration in `premium_screen.dart`.

### Verification

- Flutter analysis passed for the changed feature files.
- Debug builds were launched on Khushi's wireless iPhone.
- Hot reload and hot restart were exercised through the Flutter debug session.
