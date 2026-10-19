import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/app_colors.dart';

/// Night-sky backdrop with soft color orbs used across screens.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child, this.intensity = 1});
  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    Widget orb(Color c, double size) => IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withValues(alpha: 0.35 * intensity), c.withValues(alpha: 0)]),
            ),
          ),
        );
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
      Positioned(top: -120, left: -100, child: orb(AppColors.violet, 360)),
      Positioned(top: 140, right: -140, child: orb(AppColors.pink, 320)),
      Positioned(bottom: -160, left: -60, child: orb(AppColors.cyan, 300)),
      Positioned.fill(child: child),
    ]);
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient = AppColors.primaryGradient,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled || loading ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.gradient});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? AppColors.surface.withValues(alpha: 0.8) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.stroke),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.violet, strokeWidth: 2.6));
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textFaint),
          const SizedBox(height: 16),
          Text(l.errorText(error), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(l.retry)),
          ],
        ]),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.emoji, required this.title, this.subtitle, this.action});
  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Text(emoji, style: const TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

class InterestChip extends StatelessWidget {
  const InterestChip({super.key, required this.keyName, this.selected = false, this.onTap, this.highlight = false});
  final String keyName;
  final bool selected;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${kInterestEmoji[keyName] ?? '✨'} ${context.l10n.interest(keyName)}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected || highlight ? AppColors.primaryGradient : null,
        color: selected || highlight ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: selected || highlight ? Colors.transparent : AppColors.stroke),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message, {String? confirm, bool danger = false}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel, style: const TextStyle(color: AppColors.textMuted))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm ?? l.confirm, style: TextStyle(color: danger ? AppColors.danger : AppColors.violet)),
        ),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: error ? AppColors.danger : AppColors.mint, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
}
