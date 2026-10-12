import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Brand seeds close to the apps' own accents, so tests exercise the palettes
/// the apps will actually derive.
const seeds = <String, Color>{
  'brew-violet': Color(0xFF7C4DFF),
  'brewwire-blue': Color(0xFF1E88E5),
  'wealth-green': Color(0xFF2E7D32),
  'neuro-amber': Color(0xFFFF8F00),
};

ThemeData themeFor(Color seed, Brightness brightness) =>
    buildBrewTheme(colors: BrewColors.fromSeed(seed, brightness: brightness));

Future<void> pumpBrew(
  WidgetTester tester,
  Widget child, {
  Color seed = const Color(0xFF7C4DFF),
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeFor(seed, brightness),
      home: Scaffold(body: child),
    ),
  );
}
