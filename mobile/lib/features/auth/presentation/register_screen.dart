import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/locale_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final locale = ref.read(localeProvider).languageCode;
      final sent = await ref.read(authControllerProvider.notifier).register(_email.text.trim().toLowerCase(), _password.text, locale);
      if (!mounted) return;
      context.push(Uri(path: '/verify', queryParameters: {'email': sent.email, 'dev': ?sent.devCode}).toString());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.registerTitle,
      subtitle: l.registerSubtitle,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: (v) => validateEmail(context, v),
              decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: l.password,
              autofill: AutofillHints.newPassword,
              validator: (v) => validatePassword(context, v),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirm,
              label: l.confirmPassword,
              validator: (v) => v != _password.text ? l.validationPasswordMatch : null,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(l.validationPassword, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            const SizedBox(height: 24),
            GradientButton(label: l.register, loading: _loading, onPressed: _submit),
            const SizedBox(height: 16),
            Text(l.termsNote, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
