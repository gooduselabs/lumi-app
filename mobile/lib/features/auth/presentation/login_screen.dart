import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/common.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim().toLowerCase();
    try {
      await ref.read(authControllerProvider.notifier).login(email, _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        // The server just emailed a fresh code.
        context.push(Uri(path: '/verify', queryParameters: {'email': email}).toString());
      } else {
        showSnack(context, context.l10n.errorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.loginTitle,
      subtitle: l.loginSubtitle,
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
              autofill: AutofillHints.password,
              validator: (v) => (v ?? '').isEmpty ? l.validationRequired : null,
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => context.push('/forgot'), child: Text(l.forgotPassword)),
            ),
            const SizedBox(height: 12),
            GradientButton(label: l.login, loading: _loading, onPressed: _submit),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(l.noAccount),
              TextButton(onPressed: () => context.pushReplacement('/register'), child: Text(l.register)),
            ]),
          ]),
        ),
      ),
    );
  }
}
