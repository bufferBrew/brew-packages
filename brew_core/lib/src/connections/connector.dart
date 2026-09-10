/// One field a connector needs from the user.
///
/// Comes from `core.connectors.fields`, not from Dart, so the settings screen
/// can render a form for a connector added after the app shipped.
class ConnectorField {
  const ConnectorField({
    required this.key,
    required this.label,
    required this.secret,
    required this.required,
    this.hint = '',
    this.help = '',
  });

  final String key;
  final String label;

  /// Secret fields go into the ciphertext and are never read back. Non-secret
  /// fields (Notion's database id) live in `metadata` and are shown normally.
  final bool secret;

  final bool required;
  final String hint;
  final String help;

  static ConnectorField fromJson(Map<String, dynamic> json) => ConnectorField(
        key: (json['key'] as String?) ?? '',
        label: (json['label'] as String?) ?? (json['key'] as String?) ?? '',
        secret: (json['secret'] as bool?) ?? false,
        required: (json['required'] as bool?) ?? false,
        hint: (json['hint'] as String?) ?? '',
        help: (json['help'] as String?) ?? '',
      );
}

/// How a connector is established.
enum ConnectorKind {
  /// The user pastes credentials into a form.
  apiKey,

  /// Tokens arrive from a provider redirect. The settings screen offers a
  /// "Connect" button rather than a form — there is no token for the user to
  /// type, and accepting one would mean trusting client-supplied credentials.
  oauth;

  static ConnectorKind parse(String? value) =>
      value == 'oauth' ? ConnectorKind.oauth : ConnectorKind.apiKey;
}

/// A connectable third-party service, from `core.connectors`.
class Connector {
  const Connector({
    required this.provider,
    required this.displayName,
    required this.kind,
    required this.icon,
    required this.helpUrl,
    required this.fields,
  });

  final String provider;
  final String displayName;
  final ConnectorKind kind;

  /// Material icon name. A string rather than an IconData because it comes from
  /// the database; the settings screen maps it, falling back to a generic plug.
  final String icon;

  final String helpUrl;
  final List<ConnectorField> fields;

  static Connector fromJson(Map<String, dynamic> json) => Connector(
        provider: (json['provider'] as String?) ?? '',
        displayName: (json['display_name'] as String?) ?? '',
        kind: ConnectorKind.parse(json['kind'] as String?),
        icon: (json['icon'] as String?) ?? '',
        helpUrl: (json['help_url'] as String?) ?? '',
        fields: ((json['fields'] as List<dynamic>?) ?? const [])
            .map((e) => ConnectorField.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One configured connection, metadata only.
///
/// There is no secret field and there cannot be one: the column grants in
/// `0042_core_connections.sql` exclude the ciphertext and `core-connections`
/// has no action that returns it. [secretHints] holds the last four characters
/// per field.
class Connection {
  const Connection({
    required this.provider,
    required this.accountId,
    required this.accountLabel,
    required this.status,
    required this.secretHints,
    required this.metadata,
    required this.lastError,
    required this.updatedAt,
  });

  final String provider;
  final String accountId;
  final String accountLabel;

  /// 'active', 'disconnected' or 'error'.
  final String status;

  final Map<String, String> secretHints;
  final Map<String, String> metadata;
  final String lastError;
  final DateTime updatedAt;

  bool get isHealthy => status == 'active';

  String maskedHint(String field) {
    final hint = secretHints[field];
    return hint == null || hint.isEmpty ? '••••' : '••••$hint';
  }

  static Connection fromJson(Map<String, dynamic> json) => Connection(
        provider: (json['provider'] as String?) ?? '',
        accountId: (json['account_id'] as String?) ?? '',
        accountLabel: (json['account_label'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'active',
        secretHints: _stringMap(json['secret_hints']),
        metadata: _stringMap(json['metadata']),
        lastError: (json['last_error'] as String?) ?? '',
        updatedAt: DateTime.tryParse(
              (json['updated_at'] ?? json['created_at']) as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  static Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        '${entry.key}': entry.value == null ? '' : '${entry.value}',
    };
  }
}

/// The connectors registry plus what this user has configured.
class ConnectionsState {
  const ConnectionsState({
    required this.connectors,
    required this.connections,
  });

  const ConnectionsState.empty()
      : connectors = const [],
        connections = const [];

  final List<Connector> connectors;
  final List<Connection> connections;

  /// The connection for [provider].
  ///
  /// [accountId] null — the default — means "whichever one this user has",
  /// preferring the unnamed account and otherwise taking the first. That
  /// matters because connections do not all have an empty account id: anything
  /// created through an OAuth flow carries the provider's own account id (a
  /// Google `sub`, a Notion workspace id), so a lookup pinned to '' silently
  /// misses every OAuth connection. See migration 0047.
  ///
  /// Pass an explicit [accountId] when the app genuinely distinguishes accounts
  /// — a user can hold two Gmail inboxes, and only the caller knows which is
  /// meant.
  Connection? connectionFor(String provider, {String? accountId}) {
    Connection? fallback;
    for (final c in connections) {
      if (c.provider != provider) continue;
      if (accountId != null) {
        if (c.accountId == accountId) return c;
        continue;
      }
      if (c.accountId.isEmpty) return c;
      fallback ??= c;
    }
    return fallback;
  }

  /// Every connection for [provider], for apps that list accounts.
  List<Connection> connectionsFor(String provider) =>
      connections.where((c) => c.provider == provider).toList();

  /// Only the connectors an app actually uses, in registry order. An app that
  /// passes nothing gets the whole list.
  List<Connector> visible(Set<String> only) => only.isEmpty
      ? connectors
      : connectors.where((c) => only.contains(c.provider)).toList();
}
