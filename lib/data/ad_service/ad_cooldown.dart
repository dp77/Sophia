/// Remembers when the last full-screen ad (rewarded, rewarded interstitial or
/// interstitial) was closed, so screens can skip showing another one right away.
class AdCooldown {
  static const window = Duration(seconds: 30);

  static DateTime? _lastAdClosedAt;

  /// Call when a full-screen ad is dismissed.
  static void markAdShown() => _lastAdClosedAt = DateTime.now();

  /// True for [window] after the last full-screen ad closed.
  static bool get isActive {
    final last = _lastAdClosedAt;
    return last != null && DateTime.now().difference(last) < window;
  }
}
