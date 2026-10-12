import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// The whole gallery, in light and dark, for each app-like seed, against
/// Flutter's accessibility guidelines. This is what keeps a derived palette
/// from shipping unreadable text.
void main() {
  for (final MapEntry(key: name, value: seed) in seeds.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('gallery meets a11y guidelines: $name ${brightness.name}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpBrew(
          tester,
          const BrewComponentGallery(animate: false),
          seed: seed,
          brightness: brightness,
          size: const Size(420, 3200),
        );
        // The loading button's spinner never settles.
        await tester.pump(const Duration(milliseconds: 500));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  // Negative control: proves the contrast check can fail, so the passes above
  // mean something.
  testWidgets('an unreadable palette fails the contrast check', (tester) async {
    final handle = tester.ensureSemantics();
    final base = BrewColors.fromSeed(seeds.values.first);
    final unreadable = base.copyWith(
      text: base.background.withValues(alpha: 1),
      textSecondary: base.background,
    );
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildBrewTheme(colors: unreadable),
        home: const Scaffold(
          body: BrewEmptyState(title: 'Invisible', message: 'Also invisible'),
        ),
      ),
    );
    final result = await textContrastGuideline.evaluate(tester);
    expect(result.passed, isFalse);
    handle.dispose();
  });
}
