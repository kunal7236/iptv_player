import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    WidgetsBinding.instance.addTimingsCallback(_logSlowFrames);
  }

  runApp(const IPTVApp());
}

void _logSlowFrames(List<FrameTiming> timings) {
  var slowFrameCount = 0;

  for (final timing in timings) {
    final buildMs = timing.buildDuration.inMilliseconds;
    final rasterMs = timing.rasterDuration.inMilliseconds;
    if (buildMs > 16 || rasterMs > 16) {
      slowFrameCount++;
      debugPrint(
        'Slow frame: build=${buildMs}ms raster=${rasterMs}ms total=${timing.totalSpan.inMilliseconds}ms',
      );
    }
  }

  if (slowFrameCount >= 3) {
    debugPrint(
      'Possible freeze: $slowFrameCount slow frame(s) in the latest batch.',
    );
  }
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
