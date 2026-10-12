import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/brew_theme.dart';
import '../tokens/brew_layout.dart';

/// A text field on the theme's input decoration, with a show/hide toggle
/// when [obscure] is set.
class BrewTextField extends StatefulWidget {
  const BrewTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;

  /// Ignored when [obscure] is set; the reveal toggle takes that slot.
  final Widget? suffix;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<BrewTextField> createState() => _BrewTextFieldState();
}

class _BrewTextFieldState extends State<BrewTextField> {
  late bool _hidden = widget.obscure;

  /// "Show password", not just "Show": with two secret fields on a screen a
  /// bare verb doesn't say which one.
  String get _toggleTooltip {
    final what = widget.label?.toLowerCase() ?? 'text';
    return _hidden ? 'Show $what' : 'Hide $what';
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    focusNode: widget.focusNode,
    enabled: widget.enabled,
    autofocus: widget.autofocus,
    obscureText: _hidden,
    enableSuggestions: !widget.obscure,
    autocorrect: !widget.obscure,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    autofillHints: widget.autofillHints,
    validator: widget.validator,
    onChanged: widget.onChanged,
    onFieldSubmitted: widget.onSubmitted,
    maxLines: widget.obscure ? 1 : widget.maxLines,
    inputFormatters: widget.inputFormatters,
    style: context.brewType.body,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helper,
      helperMaxLines: 3,
      errorText: widget.errorText,
      errorMaxLines: 3,
      prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
      suffixIcon: widget.obscure
          ? IconButton(
              tooltip: _toggleTooltip,
              icon: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _hidden = !_hidden),
            )
          : widget.suffix,
    ),
  );
}

/// Input for a secret such as an API key.
///
/// A saved key is shown only as its [keyHint] (`••••1234`) and can't be
/// revealed — brew_core never returns it — so the field is always for typing a
/// *new* key. The reveal toggle shows what you're typing, nothing more.
class BrewApiKeyField extends StatelessWidget {
  const BrewApiKeyField({
    super.key,
    required this.controller,
    this.keyHint,
    this.label = 'API key',
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// Last characters of the saved key, or null when none is saved.
  final String? keyHint;
  final String label;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.brewColors;
    final saved = keyHint != null && keyHint!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (saved) ...[
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: c.success),
              const SizedBox(width: BrewSpacing.xs + 2),
              Flexible(
                child: Text(
                  'Saved ••••$keyHint',
                  style: context.brewType.label.copyWith(color: c.successText),
                ),
              ),
            ],
          ),
          const SizedBox(height: BrewSpacing.sm),
        ],
        BrewTextField(
          controller: controller,
          label: label,
          hint: saved ? 'Paste a new key to replace it' : 'Paste your key',
          obscure: true,
          enabled: enabled,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}
