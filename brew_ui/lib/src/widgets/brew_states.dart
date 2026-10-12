import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_layout.dart';
import 'brew_button.dart';

/// "Nothing here yet", with an optional way forward.
///
/// Icon-only on purpose: an illustration is part of an app's identity
/// (BrewVoyage's dotted route), so apps pass their own as [art].
class BrewEmptyState extends StatelessWidget {
  const BrewEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.art,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;

  /// Replaces the icon well.
  final Widget? art;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter, for an empty tab rather than a whole screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final type = context.brewType;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? BrewSpacing.lg : BrewSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              art ??
                  ExcludeSemantics(
                    child: Container(
                      width: compact ? 56 : 72,
                      height: compact ? 56 : 72,
                      decoration: BoxDecoration(
                        color: c.accentSubtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 26 : 32,
                        color: c.accentStrong,
                      ),
                    ),
                  ),
              SizedBox(height: compact ? BrewSpacing.md : BrewSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? type.titleSmall : type.title,
              ),
              if (message != null) ...[
                const SizedBox(height: BrewSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: type.bodySmall,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? BrewSpacing.md : BrewSpacing.xl),
                BrewButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether a failure is the network's fault or the server's.
enum BrewErrorKind { offline, server }

/// Classifies [error] (from BREW's `classifyError`).
///
/// Conservative: only failures where the request never reached a server
/// count as offline. Telling someone to check their wifi when the real
/// problem is an RLS rejection sends them off to debug the wrong thing.
/// Matched by name where the type lives in `dart:io` or `package:http`, which
/// brew_ui doesn't depend on.
BrewErrorKind classifyError(Object? error) {
  if (error == null) return BrewErrorKind.server;
  if (error is TimeoutException) return BrewErrorKind.offline;
  final type = error.runtimeType.toString();
  if (type == 'ClientException' || type == 'SocketException') {
    return BrewErrorKind.offline;
  }
  final text = error.toString().toLowerCase();
  const markers = [
    'socketexception',
    'failed host lookup',
    'connection refused',
    'connection closed',
    'network is unreachable',
    'failed to fetch',
    'xmlhttprequest error',
  ];
  return markers.any(text.contains)
      ? BrewErrorKind.offline
      : BrewErrorKind.server;
}

/// A failure with a retry, and the raw error in a collapsed, selectable
/// block so it can be copied into a bug report.
class BrewErrorState extends StatefulWidget {
  const BrewErrorState({
    super.key,
    this.title,
    this.message,
    this.error,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  /// Defaults by kind: "You're offline" or "Something went wrong".
  final String? title;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  State<BrewErrorState> createState() => _BrewErrorStateState();
}

class _BrewErrorStateState extends State<BrewErrorState> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final type = context.brewType;
    final kind = classifyError(widget.error);
    final offline = kind == BrewErrorKind.offline;
    final title =
        widget.title ?? (offline ? "You're offline" : 'Something went wrong');
    final message =
        widget.message ??
        (offline
            ? 'Check your connection and try again.'
            : 'That didn’t work. Trying again usually helps.');

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          widget.compact ? BrewSpacing.lg : BrewSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: widget.compact ? 32 : 40,
                color: c.dangerText,
              ),
              const SizedBox(height: BrewSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: widget.compact ? type.titleSmall : type.title,
                ),
              ),
              const SizedBox(height: BrewSpacing.sm),
              Text(message, textAlign: TextAlign.center, style: type.bodySmall),
              if (widget.onRetry != null) ...[
                const SizedBox(height: BrewSpacing.lg),
                BrewButton(
                  label: widget.retryLabel,
                  icon: Icons.refresh_rounded,
                  variant: BrewButtonVariant.secondary,
                  onPressed: widget.onRetry,
                ),
              ],
              if (widget.error != null) ...[
                const SizedBox(height: BrewSpacing.sm),
                TextButton(
                  onPressed: () => setState(() => _details = !_details),
                  child: Text(_details ? 'Hide details' : 'Show details'),
                ),
                if (_details)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(BrewSpacing.md),
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: context.brewShape.controlRadius,
                    ),
                    child: SelectableText(
                      '${widget.error}',
                      style: type.bodySmall.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
