import 'dart:math';

/// Realistic latency simulator. 800–1200 ms per the locked decision in the
/// Mobile R0.1 plan (sprint doc § "Auth in mock mode").
///
/// Use sparingly — heavy ops (sign-in, photo upload) take this; lightweight
/// reads (list events, get event by id) can use [shortDelay] for snappier UX.
class MockLatency {
  MockLatency._();

  static final _rng = Random();

  /// Default 800–1200 ms range.
  static Future<void> simulate({int minMs = 800, int maxMs = 1200}) {
    final ms = minMs + _rng.nextInt(maxMs - minMs + 1);
    return Future<void>.delayed(Duration(milliseconds: ms));
  }

  /// Snappier 250–450 ms range for trivial reads.
  static Future<void> shortDelay() => simulate(minMs: 250, maxMs: 450);

  /// 500–800 ms — list/feed loads.
  static Future<void> mediumDelay() => simulate(minMs: 500, maxMs: 800);
}
