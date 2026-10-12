import 'package:brew_ui/brew_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('BrewButton', () {
    testWidgets('taps, and exposes a button role', (tester) async {
      var taps = 0;
      await pumpBrew(
        tester,
        Center(
          child: BrewButton(label: 'Save', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('Save'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(BrewButton)),
        matchesSemantics(
          label: 'Save',
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('loading blocks taps but keeps the label', (tester) async {
      var taps = 0;
      await pumpBrew(
        tester,
        Center(
          child: BrewButton(
            label: 'Save',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(BrewButton), warnIfMissed: false);
      expect(taps, 0);
      expect(find.bySemanticsLabel('Save'), findsOneWidget);
    });

    testWidgets('every size clears the 48dp tap target', (tester) async {
      await pumpBrew(
        tester,
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in BrewButtonSize.values)
                BrewButton(label: s.name, size: s, onPressed: () {}),
            ],
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('BrewTextField reveal toggle shows and hides', (tester) async {
    await pumpBrew(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: BrewTextField(label: 'Password', obscure: true),
      ),
    );
    EditableText field() => tester.widget(find.byType(EditableText));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('a custom leading mark replaces the icon and stays silent', (
    tester,
  ) async {
    await pumpBrew(
      tester,
      Center(
        child: BrewSignInButton(
          kind: BrewSignInKind.google,
          variant: BrewButtonVariant.primary,
          leading: const Text('G', key: ValueKey('mark')),
          onPressed: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('mark')), findsOneWidget);
    expect(find.byIcon(BrewSignInKind.google.icon), findsNothing);
    expect(find.bySemanticsLabel('Continue with Google'), findsOneWidget);
  });

  testWidgets('BrewApiKeyField only ever shows the hint', (tester) async {
    await pumpBrew(
      tester,
      Padding(
        padding: const EdgeInsets.all(16),
        child: BrewApiKeyField(
          controller: TextEditingController(),
          keyHint: '1234',
        ),
      ),
    );
    expect(find.text('Saved ••••1234'), findsOneWidget);
    expect(find.text('Paste a new key to replace it'), findsOneWidget);
  });

  group('states', () {
    test('classifyError separates network from server failures', () {
      expect(
        classifyError(Exception('Failed host lookup')),
        BrewErrorKind.offline,
      );
      expect(
        classifyError(Exception('XMLHttpRequest error')),
        BrewErrorKind.offline,
      );
      expect(
        classifyError(Exception('permission denied for table')),
        BrewErrorKind.server,
      );
      expect(classifyError(null), BrewErrorKind.server);
    });

    testWidgets('BrewErrorState offers retry and copyable details', (
      tester,
    ) async {
      var retried = false;
      await pumpBrew(
        tester,
        BrewErrorState(
          error: Exception('connection refused'),
          onRetry: () => retried = true,
        ),
      );
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);

      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.text('Show details'));
      await tester.pump();
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('BrewEmptyState action', (tester) async {
      var acted = false;
      await pumpBrew(
        tester,
        BrewEmptyState(
          title: 'Nothing yet',
          message: 'Add one',
          actionLabel: 'Add',
          onAction: () => acted = true,
        ),
      );
      await tester.tap(find.text('Add'));
      expect(acted, isTrue);
    });
  });

  group('dialogs', () {
    Future<T?> open<T>(
      WidgetTester tester,
      Future<T> Function(BuildContext) show,
    ) async {
      T? result;
      await pumpBrew(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await show(context),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm resolves true on confirm, false on cancel', (
      tester,
    ) async {
      bool? result;
      await pumpBrew(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showBrewConfirmDialog(
              context,
              title: 'Delete?',
              confirmLabel: 'Delete',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('text input validates and returns the trimmed value', (
      tester,
    ) async {
      String? result;
      await pumpBrew(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showBrewTextInputDialog(
              context,
              title: 'Rename',
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '  Trip  ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, 'Trip');
      expect(open, isNotNull);
    });
  });

  group('BrewEmailPasswordForm', () {
    testWidgets('validates before calling onSubmit', (tester) async {
      var calls = 0;
      await pumpBrew(
        tester,
        BrewEmailPasswordForm(
          onSubmit: (e, p, s) async {
            calls++;
            return null;
          },
        ),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(calls, 0);

      await tester.enterText(find.byType(TextFormField).first, 'nope');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.textContaining('look like an email'), findsOneWidget);
    });

    testWidgets('sign-up enforces password length and shows the notice', (
      tester,
    ) async {
      (String, String, bool)? got;
      await pumpBrew(
        tester,
        BrewEmailPasswordForm(
          onSubmit: (e, p, s) async {
            got = (e, p, s);
            return 'Check your inbox';
          },
        ),
      );
      await tester.tap(find.text('New here? Create an account'));
      await tester.pump();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), ' kj@example.com ');
      await tester.enterText(fields.at(1), 'short');
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(find.text('Use at least 8 characters'), findsOneWidget);

      await tester.enterText(fields.at(1), 'long-enough');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(got, ('kj@example.com', 'long-enough', true));
      expect(find.text('Check your inbox'), findsOneWidget);
    });

    testWidgets('shows a thrown error’s message', (tester) async {
      await pumpBrew(
        tester,
        BrewEmailPasswordForm(
          onSubmit: (e, p, s) async => throw _Err('Invalid login credentials'),
        ),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'kj@example.com');
      await tester.enterText(fields.at(1), 'x');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid login credentials'), findsOneWidget);
    });
  });

  testWidgets('email form submit can step down to secondary', (tester) async {
    await pumpBrew(
      tester,
      BrewEmailPasswordForm(
        submitVariant: BrewButtonVariant.secondary,
        onSubmit: (e, p, s) async => null,
      ),
    );
    final button = tester.widget<BrewButton>(
      find.widgetWithText(BrewButton, 'Sign in'),
    );
    expect(button.variant, BrewButtonVariant.secondary);
  });

  testWidgets('BrewBackendSetupForm blocks invalid input', (tester) async {
    String? submitted;
    await pumpBrew(
      tester,
      BrewBackendSetupForm(
        validate: (u, k) => u.startsWith('https://') ? null : 'Bad URL',
        onSubmit: (u, k) async => submitted = u,
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'abc');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(find.text('Bad URL'), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(fields.at(0), 'https://abc.supabase.co');
    await tester.enterText(fields.at(1), 'anon');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(submitted, 'https://abc.supabase.co');
  });

  group('settings', () {
    testWidgets('theme mode tile reports the choice', (tester) async {
      ThemeMode? picked;
      await pumpBrew(
        tester,
        BrewThemeModeTile(
          value: ThemeMode.system,
          onChanged: (m) => picked = m,
        ),
      );
      await tester.tap(find.text('Dark'));
      expect(picked, ThemeMode.dark);
    });

    testWidgets('account: anonymous shows link actions, no sign-out', (
      tester,
    ) async {
      await pumpBrew(
        tester,
        BrewAccountSection(
          accountLabel: null,
          isAnonymous: true,
          onSignOut: () async {},
          linkActions: [
            BrewSignInButton(
              kind: BrewSignInKind.google,
              label: 'Link Google',
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.text('Link Google'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('account: sign-out asks first', (tester) async {
      var out = false;
      await pumpBrew(
        tester,
        BrewAccountSection(
          accountLabel: 'kj@example.com',
          onSignOut: () async => out = true,
        ),
      );
      expect(find.text('Signed in as kj@example.com'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(out, isFalse);
      await tester.tap(find.widgetWithText(BrewButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(out, isTrue);
    });

    testWidgets('credential tile: save needs a key, then calls onSave', (
      tester,
    ) async {
      final saved = <String>[];
      await pumpBrew(
        tester,
        SingleChildScrollView(
          child: BrewCredentialTile(
            title: 'Anthropic',
            onSave: (k) async => saved.add(k),
          ),
        ),
      );
      expect(find.text('Not set'), findsOneWidget);
      await tester.tap(find.text('Anthropic'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Paste a key first'), findsOneWidget);
      expect(saved, isEmpty);

      await tester.enterText(find.byType(TextFormField), ' sk-123 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, ['sk-123']);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('credential tile: a failed test shows its error', (
      tester,
    ) async {
      await pumpBrew(
        tester,
        SingleChildScrollView(
          child: BrewCredentialTile(
            title: 'Anthropic',
            keyHint: '9f2a',
            initiallyExpanded: true,
            onSave: (_) async {},
            onTest: () async => throw Exception('401 invalid key'),
          ),
        ),
      );
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('401 invalid key'), findsOneWidget);
    });
  });

  group('BrewAdaptiveShell', () {
    Widget shell(ValueChanged<int> onSelected) => BrewAdaptiveShell(
      destinations: const [
        BrewNavDestination(icon: Icons.home_outlined, label: 'Home'),
        BrewNavDestination(icon: Icons.settings_outlined, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: onSelected,
      body: const Text('body'),
    );

    testWidgets('bottom bar on phones', (tester) async {
      int? picked;
      await pumpBrew(tester, shell((i) => picked = i));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.tap(find.text('Settings'));
      expect(picked, 1);
    });

    testWidgets('rail on tablets, extended on desktop', (tester) async {
      await pumpBrew(tester, shell((_) {}), size: const Size(800, 800));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );

      await pumpBrew(tester, shell((_) {}), size: const Size(1200, 800));
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
    });
  });

  testWidgets('shimmer is static under reduced motion', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: BrewShimmer.lines())),
      ),
    );
    // pumpAndSettle would time out if the shimmer were still repeating.
    await tester.pumpAndSettle();
    expect(SemanticsBinding.instance, isNotNull);
  });
}

class _Err implements Exception {
  _Err(this.message);
  final String message;
}
