import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n_ext.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lumi_avatar.dart';
import '../../../core/widgets/lumi_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const Spacer(),
              const _FloatingAvatars(),
              const SizedBox(height: 28),
              const LumiLogo(size: 72, showWordmark: true),
              const SizedBox(height: 20),
              Text(l.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.25)),
              const SizedBox(height: 12),
              Text(l.welcomeSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
              const Spacer(),
              GradientButton(label: l.getStarted, onPressed: () => context.push('/register')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(onPressed: () => context.push('/login'), child: Text(l.haveAccount)),
              ),
              const SizedBox(height: 8),
              Text(l.termsNote, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FloatingAvatars extends StatefulWidget {
  const _FloatingAvatars();
  @override
  State<_FloatingAvatars> createState() => _FloatingAvatarsState();
}

class _FloatingAvatarsState extends State<_FloatingAvatars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const items = [('a03', -110.0, 10.0, 54.0), ('a10', -40.0, -30.0, 64.0), ('a17', 40.0, -10.0, 58.0), ('a22', 110.0, 20.0, 50.0)];
    return SizedBox(
      height: 110,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          for (final (i, it) in items.indexed)
            Transform.translate(
              offset: Offset(it.$2, it.$3 + (i.isEven ? 1 : -1) * 8 * Curves.easeInOut.transform(_c.value)),
              child: LumiAvatar(avatarId: it.$1, size: it.$4, ring: i == 1),
            ),
        ]),
      ),
    );
  }
}
