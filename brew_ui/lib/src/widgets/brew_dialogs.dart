import 'package:flutter/material.dart';

import 'brew_button.dart';
import 'brew_fields.dart';

/// Asks a yes/no question. Resolves to false on cancel or dismiss.
///
/// [destructive] paints the confirm button as danger. Say what will be lost
/// in [message], e.g. "This removes the key from every Brew app."
Future<bool> showBrewConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        BrewButton(
          label: cancelLabel,
          variant: BrewButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        BrewButton(
          label: confirmLabel,
          variant: destructive
              ? BrewButtonVariant.danger
              : BrewButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for one line of text. Resolves to the trimmed value, or null on
/// cancel.
Future<String?> showBrewTextInputDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String initialValue = '',
  String confirmLabel = 'Save',
  String cancelLabel = 'Cancel',
  FormFieldValidator<String>? validator,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(
    title: title,
    label: label,
    hint: hint,
    initialValue: initialValue,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    validator: validator,
  ),
);

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.validator,
  });

  final String title;
  final String? label;
  final String? hint;
  final String initialValue;
  final String confirmLabel;
  final String cancelLabel;
  final FormFieldValidator<String>? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() ?? true) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: BrewTextField(
        controller: _controller,
        label: widget.label,
        hint: widget.hint,
        autofocus: true,
        validator: widget.validator,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      BrewButton(
        label: widget.cancelLabel,
        variant: BrewButtonVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
      BrewButton(label: widget.confirmLabel, onPressed: _submit),
    ],
  );
}
