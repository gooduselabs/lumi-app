import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_logo.dart';
import '../../auth/application/auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      body: GlowBackground(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LumiLogo(size: 96, showWordmark: true),
            const SizedBox(height: 32),
            if (state is AuthOffline) ...[
              ErrorView(error: state.error, onRetry: ref.read(authControllerProvider.notifier).restore),
              TextButton(onPressed: ref.read(authControllerProvider.notifier).logout, child: Text(context.l10n.logout)),
            ] else
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ]),
        ),
      ),
    );
  }
}
