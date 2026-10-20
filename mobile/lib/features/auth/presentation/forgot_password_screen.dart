import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/code_input.dart';
import '../../../core/widgets/common.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final sent = await ref.read(authControllerProvider.notifier).forgot(_email.text.trim().toLowerCase());
      if (!mounted) return;
      context.push(Uri(path: '/reset', queryParameters: {'email': sent.email, 'dev': ?sent.devCode}).toString());
    } catch (err) {
      final e = err is ApiException ? err : ApiException('UNKNOWN', '$err');
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.forgotTitle,
      subtitle: l.forgotSubtitle,
      child: Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => validateEmail(context, v),
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
          ),
          const SizedBox(height: 24),
          GradientButton(label: l.sendCode, loading: _loading, onPressed: _submit),
        ]),
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email, this.devCode});
  final String email;
  final String? devCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.length != 6 || !_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(widget.email, _code.text, _pw.text);
      if (mounted) showSnack(context, context.l10n.passwordChanged);
    } catch (err) {
      final e = err is ApiException ? err : ApiException('UNKNOWN', '$err');
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.resetTitle,
      subtitle: l.resetSubtitle(widget.email),
      child: Form(
        key: _form,
        child: Column(children: [
          CodeInput(controller: _code),
          if (widget.devCode != null) DevCodeBanner(code: widget.devCode!, onTap: () => _code.text = widget.devCode!),
          const SizedBox(height: 20),
          PasswordField(controller: _pw, label: l.newPassword, autofill: AutofillHints.newPassword, validator: (v) => validatePassword(context, v)),
          const SizedBox(height: 14),
          PasswordField(
            controller: _confirm,
            label: l.confirmPassword,
            validator: (v) => v != _pw.text ? l.validationPasswordMatch : null,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          GradientButton(label: l.resetAction, loading: _loading, onPressed: _submit),
        ]),
      ),
    );
  }
}
