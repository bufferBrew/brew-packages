import 'dart:convert';

import 'package:brew_core/brew_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = 'https://abc.supabase.co';
const _key = 'anon-key';

class _MemoryStore implements BrewConfigStore {
  _MemoryStore([this.value]);
  BrewConfig? value;

  @override
  Future<BrewConfig?> read() async => value;
  @override
  Future<void> save(BrewConfig config) async => value = config;
  @override
  Future<void> clear() async => value = null;
}

final _saved = BrewConfig(
  supabaseUrl: 'https://saved.example.com',
  supabaseAnonKey: 'saved',
  source: BrewConfigSource.saved,
);

void main() {
  group('BrewConfig', () {
    test('validate accepts http(s) URLs with a host', () {
      expect(BrewConfig.validate(_url, _key), isNull);
      expect(BrewConfig.validate('http://localhost:54321', _key), isNull);
    });

    test('validate rejects bad URLs and empty keys', () {
      expect(BrewConfig.validate('abc.supabase.co', _key), isNotNull);
      expect(BrewConfig.validate('ftp://abc.supabase.co', _key), isNotNull);
      expect(BrewConfig.validate(_url, '  '), isNotNull);
    });

    test('fromJson treats blank values as absent', () {
      expect(
        BrewConfig.fromJson({
          'SUPABASE_URL': '',
          'SUPABASE_ANON_KEY': '',
        }, BrewConfigSource.hosted),
        isNull,
      );
      expect(BrewConfig.fromJson({}, BrewConfigSource.hosted), isNull);
    });

    test('fromJson throws on present-but-malformed values', () {
      expect(
        () => BrewConfig.fromJson({
          'SUPABASE_URL': 'not a url',
          'SUPABASE_ANON_KEY': _key,
        }, BrewConfigSource.hosted),
        throwsA(isA<BrewConfigException>()),
      );
    });

    test('toJson round-trips through fromJson', () {
      const c = BrewConfig(
        supabaseUrl: _url,
        supabaseAnonKey: _key,
        source: BrewConfigSource.saved,
      );
      expect(BrewConfig.fromJson(c.toJson(), BrewConfigSource.saved), c);
    });
  });

  group('loadBrewConfig', () {
    test('dart-defines win over everything else', () async {
      final c = await loadBrewConfig(
        definedUrl: _url,
        definedAnonKey: _key,
        fetchHosted: () => fail('hosted config must not be fetched'),
        store: _MemoryStore(_saved),
        isWeb: true,
      );
      expect(c?.source, BrewConfigSource.dartDefine);
      expect(c?.supabaseUrl, _url);
    });

    test('a half-set dart-define is an error, not a first run', () {
      expect(
        loadBrewConfig(definedUrl: _url, store: _MemoryStore()),
        throwsA(isA<BrewConfigException>()),
      );
    });

    test('on web, a hosted config.json beats a saved one', () async {
      final c = await loadBrewConfig(
        fetchHosted: () async => {
          'SUPABASE_URL': _url,
          'SUPABASE_ANON_KEY': _key,
        },
        store: _MemoryStore(_saved),
        isWeb: true,
      );
      expect(c?.source, BrewConfigSource.hosted);
    });

    test('on web, a blank hosted config falls through to saved', () async {
      final c = await loadBrewConfig(
        fetchHosted: () async => {'SUPABASE_URL': '', 'SUPABASE_ANON_KEY': ''},
        store: _MemoryStore(_saved),
        isWeb: true,
      );
      expect(c, _saved);
    });

    test('off web, hosted config is never fetched', () async {
      final c = await loadBrewConfig(
        fetchHosted: () => fail('hosted config must not be fetched'),
        store: _MemoryStore(_saved),
        isWeb: false,
      );
      expect(c, _saved);
    });

    test('nothing configured returns null', () async {
      expect(await loadBrewConfig(store: _MemoryStore(), isWeb: false), isNull);
    });
  });

  group('SharedPrefsConfigStore', () {
    test('save, read, clear', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPrefsConfigStore();
      expect(await store.read(), isNull);

      await store.save(
        const BrewConfig(
          supabaseUrl: _url,
          supabaseAnonKey: _key,
          source: BrewConfigSource.saved,
        ),
      );
      expect((await store.read())?.supabaseUrl, _url);

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('a corrupt or stale value reads as none', () async {
      SharedPreferences.setMockInitialValues({'brew.config.v1': '{nope'});
      expect(await const SharedPrefsConfigStore().read(), isNull);

      SharedPreferences.setMockInitialValues({
        'brew.config.v1': jsonEncode({
          'SUPABASE_URL': 'bad',
          'SUPABASE_ANON_KEY': _key,
        }),
      });
      expect(await const SharedPrefsConfigStore().read(), isNull);
    });
  });

  group('fetchHostedConfig', () {
    final target = Uri.parse('https://app.example.com/config.json');

    Future<Map<String, Object?>?> fetchWith(MockClientHandler handler) =>
        fetchHostedConfig(url: target, client: MockClient(handler));

    test('returns the JSON object', () async {
      final json = await fetchWith(
        (_) async => http.Response(jsonEncode({'SUPABASE_URL': _url}), 200),
      );
      expect(json, {'SUPABASE_URL': _url});
    });

    test('an SPA fallback (index.html with 200) means absent', () async {
      expect(
        await fetchWith(
          (_) async => http.Response('<!DOCTYPE html><html></html>', 200),
        ),
        isNull,
      );
    });

    test('404 and network errors mean absent', () async {
      expect(await fetchWith((_) async => http.Response('', 404)), isNull);
      expect(
        await fetchWith((_) async => throw http.ClientException('offline')),
        isNull,
      );
    });
  });
}
