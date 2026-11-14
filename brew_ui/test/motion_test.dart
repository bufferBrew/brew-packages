import 'dart:math' as math;

import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required Widget home, bool reduced = false}) => MaterialApp(
  theme: ThemeData(pageTransitionsTheme: BrewMotion.pageTransitions),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: home,
);

void main() {
  group('BrewMotion tokens', () {
    test('pulse is a slow breath', () {
      expect(BrewMotion.pulse, const Duration(milliseconds: 900));
      expect(BrewMotion.pulse, greaterThan(BrewMotion.slow));
    });

    test('spring is slightly under-damped and settles', () {
      final s = BrewMotion.spring;
      expect(s.mass, 1);
      expect(s.stiffness, 380);
      // damping = ratio * 2 * sqrt(mass * stiffness)
      final ratio = s.damping / (2 * math.sqrt(s.mass * s.stiffness));
      expect(ratio, closeTo(0.9, 1e-9));
    });
  });

  group('BrewMotion.pageTransitions', () {
    test('covers every platform with a reduced-motion-aware builder', () {
      final builders = BrewMotion.pageTransitions.builders;
      for (final platform in TargetPlatform.values) {
        expect(
          builders[platform],
          isA<BrewReducedMotionTransitionsBuilder>(),
          reason: '$platform',
        );
      }
    });

    test('Android gets predictive back, others fade forwards', () {
      final builders = BrewMotion.pageTransitions.builders;
      final android =
          builders[TargetPlatform.android]!
              as BrewReducedMotionTransitionsBuilder;
      expect(
        android.inner,
        kIsWeb
            ? isA<FadeForwardsPageTransitionsBuilder>()
            : isA<PredictiveBackPageTransitionsBuilder>(),
      );
      for (final platform in TargetPlatform.values.where(
        (p) => p != TargetPlatform.android,
      )) {
        final b = builders[platform]! as BrewReducedMotionTransitionsBuilder;
        expect(b.inner, isA<FadeForwardsPageTransitionsBuilder>());
      }
    });

    test('forwards durations and delegated transition to inner', () {
      const inner = FadeForwardsPageTransitionsBuilder();
      const b = BrewReducedMotionTransitionsBuilder(inner);
      expect(b.transitionDuration, inner.transitionDuration);
      expect(b.reverseTransitionDuration, inner.reverseTransitionDuration);
      // The getter builds a fresh closure each call, so compare presence.
      expect(inner.delegatedTransition, isNotNull);
      expect(b.delegatedTransition, isNotNull);
    });
  });

  group('BrewReducedMotionTransitionsBuilder', () {
    Future<void> push(WidgetTester tester, {required bool reduced}) async {
      await tester.pumpWidget(
        _app(
          reduced: reduced,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Text('detail')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('reduced motion: a plain fade, no slide', (tester) async {
      await push(tester, reduced: true);
      expect(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.text('detail'),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('full motion: defers to the inner builder', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await push(tester, reduced: false);
        expect(
          find.ancestor(
            of: find.text('detail'),
            matching: find.byType(SlideTransition),
          ),
          findsWidgets,
        );
        await tester.pumpAndSettle();
        expect(find.text('detail'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('BrewFadeThrough', () {
    Widget host(int index, {bool reduced = false}) => _app(
      reduced: reduced,
      home: BrewFadeThrough(
        index: index,
        child: IndexedStack(
          index: index,
          children: const [Text('a'), Text('b')],
        ),
      ),
    );

    double opacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(BrewFadeThrough),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('starts fully shown', (tester) async {
      await tester.pumpWidget(host(0));
      expect(opacity(tester), 1);
    });

    testWidgets('fades the new tab in over BrewMotion.fast', (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      expect(opacity(tester), 0);
      await tester.pump(BrewMotion.fast ~/ 2);
      expect(opacity(tester), inExclusiveRange(0, 1));
      await tester.pump(BrewMotion.fast);
      expect(opacity(tester), 1);
    });

    testWidgets('same index does not restart the fade', (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(0));
      expect(opacity(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion switches instantly', (tester) async {
      await tester.pumpWidget(host(0, reduced: true));
      await tester.pumpWidget(host(1, reduced: true));
      expect(opacity(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('keeps the child, so tab state survives', (tester) async {
      await tester.pumpWidget(host(0));
      final stack = find.byType(IndexedStack);
      final before = tester.element(stack);
      await tester.pumpWidget(host(1));
      await tester.pumpAndSettle();
      expect(tester.element(stack), same(before));
    });
  });
}
