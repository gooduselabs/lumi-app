import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/code_input.dart';
import '../../../core/widgets/common.dart';
import '../application/auth_controller.dart';
import 'auth_widgets.dart';

class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, required this.email, this.devCode});
  final String email;
  final String? devCode;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _error = false;
  String? _devCode;
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _devCode = widget.devCode;
    _startCooldown(60);
    _code.addListener(() {
      if (_error) setState(() => _error = false);
    });
  }

  void _startCooldown(int s) {
    _timer?.cancel();
    setState(() => _cooldown = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify([String? _]) async {
    if (_code.text.length != 6 || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(widget.email, _code.text);
      // Router redirect takes over (onboarding or home).
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      showSnack(context, context.l10n.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final sent = await ref.read(authControllerProvider.notifier).resend(widget.email);
      if (!mounted) return;
      setState(() => _devCode = sent.devCode ?? _devCode);
      _startCooldown(60);
      showSnack(context, context.l10n.codeSent);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.retryAfter != null) _startCooldown(e.retryAfter!);
      showSnack(context, context.l10n.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.verifyTitle,
      subtitle: l.verifySubtitle(widget.email),
      child: Column(children: [
        CodeInput(controller: _code, onCompleted: _verify, hasError: _error),
        if (_devCode != null) DevCodeBanner(code: _devCode!, onTap: () => _code.text = _devCode!),
        const SizedBox(height: 28),
        GradientButton(label: l.verifyAction, loading: _loading, onPressed: _verify),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cooldown > 0 ? null : _resend,
          child: Text(_cooldown > 0 ? l.resendIn(_cooldown) : l.resendCode),
        ),
      ]),
    );
  }
}
