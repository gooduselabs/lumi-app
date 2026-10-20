import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/config/server_config.dart';
import '../../../core/widgets/server_address.dart';
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
            const ServerAddressTrigger(child: LumiLogo(size: 96, showWordmark: true)),
            const SizedBox(height: 32),
            if (state is AuthOffline) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(context.l10n.offlineHint, textAlign: TextAlign.center),
              ),
              Text(ServerConfig.current, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton(onPressed: ref.read(authControllerProvider.notifier).restore, child: Text(context.l10n.retry)),
              TextButton(onPressed: () => showServerAddressDialog(context, ref), child: Text(context.l10n.serverAddress)),
              TextButton(onPressed: ref.read(authControllerProvider.notifier).logout, child: Text(context.l10n.logout)),
            ] else
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ]),
        ),
      ),
    );
  }
}
