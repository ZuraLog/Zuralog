/// Zuralog Design System — Password Input Component.
///
/// Wraps [AppTextField] with a show/hide visibility toggle.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/inputs/app_text_field.dart';

/// Password text field with a tap-to-toggle visibility icon.
///
/// Delegates all styling to [AppTextField] and adds a suffix eye icon
/// that lets the user reveal or hide their password.
class ZPasswordField extends StatefulWidget {
  /// Creates a [ZPasswordField].
  const ZPasswordField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  /// Controller for reading and manipulating the field's text.
  final TextEditingController? controller;

  /// Label displayed above the field.
  final String? label;

  /// Placeholder text shown when the field is empty.
  final String? hint;

  /// Validation callback used by [Form.validate()].
  final String? Function(String?)? validator;

  /// Callback invoked on every character change.
  final ValueChanged<String>? onChanged;

  /// Whether the field accepts input.
  final bool enabled;

  @override
  State<ZPasswordField> createState() => _ZPasswordFieldState();
}

class _ZPasswordFieldState extends State<ZPasswordField> {
  bool _obscured = true;

  void _toggleVisibility() {
    setState(() => _obscured = !_obscured);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    // Inherits outline from AppTextField — see Phase 6 Plan 6.
    final field = AppTextField(
      controller: widget.controller,
      labelText: widget.label,
      hintText: widget.hint,
      obscureText: _obscured,
      onChanged: widget.onChanged,
      validator: widget.validator,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      suffixIcon: IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: colors.textSecondary,
        ),
        onPressed: widget.enabled ? _toggleVisibility : null,
        tooltip: _obscured ? 'Show password' : 'Hide password',
      ),
    );

    if (!widget.enabled) {
      return IgnorePointer(
        child: Opacity(opacity: 0.4, child: field),
      );
    }

    return field;
  }
}
