import 'dart:convert';

import 'package:brew_core/brew_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://abc.supabase.co';
const anonKey = 'anon-key';
const config = BrewConfig(
  supabaseUrl: supabaseUrl,
  supabaseAnonKey: anonKey,
  source: BrewConfigSource.dartDefine,
);

/// A minimal JWT; gotrue only decodes the payload.
String jwt(String sub) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return '${enc({'alg': 'HS256'})}.${enc({'sub': sub, 'exp': exp})}.sig';
}

Map<String, Object?> sessionJson({
  required String id,
  bool anonymous = false,
  String? email,
  String? fullName,
  String refresh = 'refresh',
}) => {
  'access_token': jwt(id),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  'refresh_token': refresh,
  'user': {
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'is_anonymous': anonymous,
    'app_metadata': {'provider': anonymous ? 'anonymous' : 'email'},
    'user_metadata': {'full_name': ?fullName},
    'created_at': '2026-01-01T00:00:00Z',
  },
};

typedef Route = http.Response Function(http.Request req);

/// GoTrue answered from a route table keyed by `METHOD /path[?grant_type]`.
class FakeGoTrue {
  final Map<String, Route> routes = {};
  final List<http.Request> requests = [];

  late final MockClient http_ = MockClient((req) async {
    requests.add(req);
    final grant = req.url.queryParameters['grant_type'];
    final key =
        '${req.method} ${req.url.path}${grant == null ? '' : '?$grant'}';
    final route = routes[key];
    if (route == null) return json({'msg': 'no route for $key'}, 404, req);
    return route(req);
  });

  static http.Response json(Object body, int status, http.Request req) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: req,
      );

  void answer(String key, Object body, {int status = 200}) =>
      routes[key] = (req) => json(body, status, req);

  SupabaseClient client() => SupabaseClient(
    supabaseUrl,
    anonKey,
    httpClient: http_,
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: MemoryAsyncStorage(),
    ),
  );
}

class MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];
  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;
  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}
