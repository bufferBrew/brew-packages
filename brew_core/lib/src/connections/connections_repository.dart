import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../llm/llm_repository.dart' show LlmSettingsException;
import 'connector.dart';

/// Reads and writes third-party credentials through `core-connections`.
///
/// Same contract as [LlmRepository]: secrets go out, never come back. An app
/// that needs to CALL a connector does it from its own Edge Function via
/// `core.get_connection_secrets` — it does not fetch the credential and make
/// the call itself.
class ConnectionsRepository {
  const ConnectionsRepository(this._client);

  final SupabaseClient _client;

  static const _function = 'core-connections';

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(_function, body: body);
      final data = res.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on FunctionException catch (e) {
      final details = e.details;
      String? message;
      String? code;
      if (details is Map) {
        message = details['detail'] as String?;
        code = details['error'] as String?;
      }
      throw LlmSettingsException(
        message ?? 'The server rejected that request (HTTP ${e.status}).',
        code: code,
      );
    } catch (e) {
      throw LlmSettingsException('Could not reach the server: $e');
    }
  }

  Future<ConnectionsState> load() async {
    final data = await _invoke({'action': 'list'});
    return ConnectionsState(
      connectors: (data['connectors'] as List<dynamic>? ?? const [])
          .map((e) => Connector.fromJson(e as Map<String, dynamic>))
          .toList(),
      connections: (data['connections'] as List<dynamic>? ?? const [])
          .map((e) => Connection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Saves every field the connector declares in one call.
  ///
  /// Partial updates are not supported: merging into ciphertext would mean
  /// decrypt-merge-re-encrypt, and a caller that thinks it is updating one
  /// field while silently dropping another is the worse failure.
  Future<void> save({
    required String provider,
    required Map<String, String> values,
    String accountId = '',
    String accountLabel = '',
  }) async {
    await _invoke({
      'action': 'set',
      'provider': provider,
      'values': values,
      'account_id': accountId,
      'account_label': accountLabel,
    });
  }

  Future<void> test({required String provider, String accountId = ''}) async {
    await _invoke({
      'action': 'test',
      'provider': provider,
      'account_id': accountId,
    });
  }

  Future<void> disconnect({
    required String provider,
    String accountId = '',
  }) async {
    await _invoke({
      'action': 'delete',
      'provider': provider,
      'account_id': accountId,
    });
  }
}

final connectionsRepositoryProvider = Provider<ConnectionsRepository>(
  (ref) => ConnectionsRepository(Supabase.instance.client),
);

/// The ecosystem's connections. App-agnostic for the same reason the LLM
/// controller is: the credentials are shared, so there is one cache per process
/// rather than one per feature.
class ConnectionsController extends AsyncNotifier<ConnectionsState> {
  @override
  Future<ConnectionsState> build() =>
      ref.read(connectionsRepositoryProvider).load();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(connectionsRepositoryProvider).load(),
    );
  }

  Future<void> save({
    required String provider,
    required Map<String, String> values,
    String accountId = '',
    String accountLabel = '',
  }) async {
    await ref
        .read(connectionsRepositoryProvider)
        .save(
          provider: provider,
          values: values,
          accountId: accountId,
          accountLabel: accountLabel,
        );
    await reload();
  }

  Future<void> test({required String provider, String accountId = ''}) => ref
      .read(connectionsRepositoryProvider)
      .test(provider: provider, accountId: accountId);

  Future<void> disconnect({
    required String provider,
    String accountId = '',
  }) async {
    await ref
        .read(connectionsRepositoryProvider)
        .disconnect(provider: provider, accountId: accountId);
    await reload();
  }
}

final connectionsProvider =
    AsyncNotifierProvider<ConnectionsController, ConnectionsState>(
      ConnectionsController.new,
    );
