import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_logo.dart';
import '../../../core/widgets/server_address.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _pwRe = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,72}$');

String? validateEmail(BuildContext c, String? v) => _emailRe.hasMatch((v ?? '').trim()) ? null : c.l10n.validationEmail;
String? validatePassword(BuildContext c, String? v) => _pwRe.hasMatch(v ?? '') ? null : c.l10n.validationPassword;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.child, this.showBack = true, this.showLogo = false});
  final bool showLogo;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowBackground(
        intensity: 0.7,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showBack)
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const SizedBox(height: 28),
                  if (showLogo) ...[
                    const ServerAddressTrigger(child: LumiLogo(size: 44)),
                    const SizedBox(height: 16),
                  ],
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4)),
                  ],
                  const SizedBox(height: 32),
                  child,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.validator, this.onSubmitted, this.autofill});
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final String? autofill;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofill != null ? [widget.autofill!] : null,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
    );
  }
}

/// Shown only when the API runs with DEV_EXPOSE_CODES=true (never in production).
class DevCodeBanner extends StatelessWidget {
  const DevCodeBanner({super.key, required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.bug_report_outlined, color: AppColors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.devCodeHint(code), style: const TextStyle(color: AppColors.amber))),
          ]),
        ),
      ),
    );
  }
}
