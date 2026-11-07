import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

const _synapse = BrewAppIdentity(
  key: 'synapse',
  name: 'Synapse',
  accent: Color(0xFF7DD3FC),
  icon: Icons.psychology_rounded,
  tagline: 'Turns a topic into a course.',
  version: '1.2.0',
);

Widget _scoped(Widget child) =>
    BrewIdentityScope(identity: _synapse, child: child);

void main() {
  test('lockup reads "<Name> · a Brew app"', () {
    expect(_synapse.lockup, 'Synapse · a Brew app');
  });

  test('identities compare by value', () {
    const copy = BrewAppIdentity(
      key: 'synapse',
      name: 'Synapse',
      accent: Color(0xFF7DD3FC),
      icon: Icons.psychology_rounded,
      tagline: 'Turns a topic into a course.',
      version: '1.2.0',
    );
    expect(copy, _synapse);
    expect(copy.hashCode, _synapse.hashCode);
  });

  testWidgets('footer and about tile read the ambient identity', (
    tester,
  ) async {
    await pumpBrew(
      tester,
      _scoped(const Column(children: [BrewAboutTile(), BrewFooter()])),
    );
    expect(find.text('Synapse'), findsOneWidget);
    expect(find.text('a Brew app · v1.2.0'), findsOneWidget);
    expect(find.text('Synapse · a Brew app · v1.2.0'), findsOneWidget);
  });

  testWidgets('about tile opens the about dialog with the tagline', (
    tester,
  ) async {
    await pumpBrew(tester, _scoped(const BrewAboutTile()));
    await tester.tap(find.byType(BrewAboutTile));
    await tester.pumpAndSettle();
    expect(find.text('Turns a topic into a course.'), findsOneWidget);
    expect(find.text('a Brew app by bufferBrew'), findsOneWidget);
  });

  testWidgets('mark falls back to the icon without a glyph image', (
    tester,
  ) async {
    await pumpBrew(
      tester,
      const Center(child: BrewAppMark(identity: _synapse, size: 64)),
    );
    expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(BrewAppMark)), const Size(64, 64));
  });

  test('brewIconByName maps registry names and falls back', () {
    expect(brewIconByName('article_rounded'), Icons.article_rounded);
    expect(brewIconByName(null), Icons.apps_rounded);
    expect(brewIconByName('no_such_icon'), Icons.apps_rounded);
  });

  for (final brightness in Brightness.values) {
    testWidgets('identity parts meet a11y guidelines: ${brightness.name}', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBrew(
        tester,
        _scoped(
          Column(
            children: [
              const BrewAboutTile(),
              BrewAppSwitcher(
                apps: [
                  const BrewSwitcherApp(key: 'synapse', name: 'Synapse'),
                  BrewSwitcherApp(
                    key: 'wire',
                    name: 'BrewWire',
                    url: Uri.parse('https://example.test'),
                  ),
                ],
                onOpen: (_) {},
              ),
              const BrewFooter(),
            ],
          ),
        ),
        brightness: brightness,
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  group('BrewAppSwitcher', () {
    final apps = [
      const BrewSwitcherApp(key: 'synapse', name: 'Synapse'),
      BrewSwitcherApp(
        key: 'wire',
        name: 'BrewWire',
        description: 'News',
        url: Uri.parse('https://example.test/wire'),
      ),
      const BrewSwitcherApp(key: 'hire', name: 'BrewHire'),
    ];

    testWidgets('marks the current app and opens only apps with a url', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpBrew(
        tester,
        _scoped(BrewAppSwitcher(apps: apps, onOpen: (a) => opened.add(a.key))),
      );
      expect(find.text('You are here'), findsOneWidget);
      await tester.tap(find.text('Synapse'));
      await tester.tap(find.text('BrewHire'));
      await tester.tap(find.text('BrewWire'));
      expect(opened, ['wire']);
    });

    testWidgets('sheet closes before handing off', (tester) async {
      final opened = <String>[];
      await pumpBrew(
        tester,
        _scoped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showBrewAppSwitcher(
                context,
                apps: apps,
                onOpen: (a) => opened.add(a.key),
              ),
              child: const Text('Apps'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();
      expect(find.text('Brew apps'), findsOneWidget);
      await tester.tap(find.text('BrewWire'));
      await tester.pumpAndSettle();
      expect(opened, ['wire']);
      expect(find.text('Brew apps'), findsNothing);
    });

    testWidgets('empty list says so', (tester) async {
      await pumpBrew(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showBrewAppSwitcher(context, apps: const [], onOpen: (_) {}),
            child: const Text('Apps'),
          ),
        ),
      );
      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();
      expect(find.text('No other Brew apps here yet.'), findsOneWidget);
    });
  });
}
