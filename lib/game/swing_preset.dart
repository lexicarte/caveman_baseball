// The saved swing. Loaded once at launch, written only when asked.
//
// A slider updates [SwingTiming.now] for this session and nothing else.
// The match reads [now], so the change is live, and the next launch is
// the shipped swing again unless this file was written.
import 'package:shared_preferences/shared_preferences.dart';

import 'swing_timing.dart';

const swingPresetKey = 'swingTiming.v1';

Future<void> loadSwingPreset() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(swingPresetKey);
    if (raw == null || raw.isEmpty) return;
    SwingTiming.now = SwingTiming.fromJson(raw);
  } catch (_) {
    // A bad preset must not stop the game starting, and must not half-apply.
    SwingTiming.reset();
  }
}

Future<void> saveSwingPreset() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(swingPresetKey, SwingTiming.now.toJson());
}

/// Shipped swing, in memory and on disk.
Future<void> clearSwingPreset() async {
  SwingTiming.reset();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(swingPresetKey);
  } catch (_) {
    // The memory reset already happened. A failed disk clear means the
    // next launch may restore the old preset; the caller surfaces that.
  }
}
