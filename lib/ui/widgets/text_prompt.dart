import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A small text-input dialog. Returns the entered text, or null if cancelled.
///
/// It is a [StatefulWidget] that owns and disposes its own [TextEditingController]
/// in its own lifecycle, so cancelling never disposes a controller that the
/// dialog's exit animation is still using (the crash the old inline dialogs hit).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String? prefixText,
  String confirmLabel = 'OK',
  bool uppercase = false,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      message: message,
      hint: hint,
      prefixText: prefixText,
      confirmLabel: confirmLabel,
      uppercase: uppercase,
      maxLength: maxLength,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.uppercase,
    this.message,
    this.hint,
    this.prefixText,
    this.maxLength,
  });

  final String title;
  final String confirmLabel;
  final bool uppercase;
  final String? message;
  final String? hint;
  final String? prefixText;
  final int? maxLength;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: widget.maxLength,
            textCapitalization: widget.uppercase
                ? TextCapitalization.characters
                : TextCapitalization.words,
            inputFormatters: widget.uppercase
                ? <TextInputFormatter>[UpperCaseFormatter()]
                : null,
            decoration: InputDecoration(
              prefixText: widget.prefixText,
              hintText: widget.hint,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.message != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Forces typed text to upper case (for channel codes).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
