import 'dart:io';

import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Pixel baselines for the gallery.
///
/// Goldens aren't portable across platforms (font rasterisation differs), so
/// baselines are made on linux/amd64 to match CI, by the manual "Regenerate
/// golden baselines" workflow. Never regenerate them on macOS. Off Linux this
/// skips. It also skips until baselines exist, so adding a golden doesn't
/// turn CI red before its baseline is committed.
void main() {
  final onLinux = Platform.isLinux;
  final hasBaselines = Directory('test/goldens/baselines').existsSync();
  final skip = !onLinux
      ? 'goldens run on Linux only'
      : !hasBaselines && !autoUpdateGoldenFiles
      ? 'no baselines yet; run the goldens workflow'
      : null;

  for (final brightness in Brightness.values) {
    testWidgets('gallery ${brightness.name}', skip: skip != null, (
      tester,
    ) async {
      await pumpBrew(
        tester,
        const BrewComponentGallery(animate: false),
        brightness: brightness,
        size: const Size(420, 2600),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(BrewComponentGallery),
        matchesGoldenFile('baselines/gallery_${brightness.name}.png'),
      );
    });
  }
}
