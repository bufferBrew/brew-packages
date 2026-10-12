import 'dart:convert';

import 'package:brew_core/brew_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A real SupabaseClient whose HTTP is answered locally, so the PostgREST
/// request the registry builds is what gets asserted.
SupabaseClient _clientReturning(
  List<Map<String, Object?>> rows, {
  void Function(http.Request)? onRequest,
}) => SupabaseClient(
  'https://abc.supabase.co',
  'anon',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((req) async {
    onRequest?.call(req);
    return http.Response(
      jsonEncode(rows),
      200,
      headers: {'content-type': 'application/json'},
      // postgrest reads the method back off the response.
      request: req,
    );
  }),
);

const _rows = [
  {
    'app': 'brew',
    'display_name': 'BREW',
    'description': 'Dashboard',
    'enabled': true,
    'sort_order': 1,
  },
  {'app': 'neurobrew', 'display_name': 'NeuroBrew', 'enabled': true},
  {'app': 'skolar', 'display_name': 'BrewSkolar', 'enabled': false},
];

void main() {
  test('reads core.apps in display order', () async {
    late http.Request seen;
    final apps = await AppRegistry(
      _clientReturning(_rows, onRequest: (r) => seen = r),
    ).list();

    expect(seen.url.path, '/rest/v1/apps');
    expect(seen.headers['Accept-Profile'], 'core');
    expect(seen.url.queryParameters['order'], startsWith('sort_order'));
    expect(apps.map((a) => a.key), ['brew', 'neurobrew', 'skolar']);
  });

  test('rows from older backends parse with defaults', () {
    final app = BrewApp.fromRow({'app': 'brewwire'});
    expect(app.displayName, 'brewwire');
    expect(app.description, '');
    expect(app.enabled, isTrue);
    expect(app.sortOrder, 100);
  });

  group('appAvailableProvider', () {
    ProviderContainer containerWith(SupabaseClient client) {
      final c = ProviderContainer(
        overrides: [brewClientProvider.overrideWithValue(client)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('true only for registered, enabled apps', () async {
      final c = containerWith(_clientReturning(_rows));
      await c.read(brewAppsProvider.future);

      expect(c.read(appAvailableProvider('neurobrew')), isTrue);
      expect(c.read(appAvailableProvider('skolar')), isFalse);
      expect(c.read(appAvailableProvider('wealthbrew')), isFalse);
    });

    test('false while loading', () {
      final c = containerWith(_clientReturning(_rows));
      expect(c.read(appAvailableProvider('neurobrew')), isFalse);
    });

    test('false when the registry cannot be read', () async {
      final failing = SupabaseClient(
        'https://abc.supabase.co',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (req) async => http.Response(
            jsonEncode({'message': 'schema not exposed', 'code': 'PGRST106'}),
            406,
            headers: {'content-type': 'application/json'},
            request: req,
          ),
        ),
      );
      final c = containerWith(failing);
      await expectLater(
        c.read(brewAppsProvider.future),
        throwsA(isA<PostgrestException>()),
      );
      expect(c.read(appAvailableProvider('neurobrew')), isFalse);
    });
  });
}
