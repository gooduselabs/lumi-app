import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lumi mark: a glowing crescent orb with a spark. Drawn in code (no image assets).
class LumiLogo extends StatefulWidget {
  const LumiLogo({super.key, this.size = 88, this.animate = true, this.showWordmark = false});
  final double size;
  final bool animate;
  final bool showWordmark;

  @override
  State<LumiLogo> createState() => _LumiLogoState();
}

class _LumiLogoState extends State<LumiLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: _LogoPainter(_c.value)),
    );
    if (!widget.showWordmark) return mark;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(height: 14),
      ShaderMask(
        shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
        child: const Text('Lumi', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white)),
      ),
    ]);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s * 0.36;
    // glow
    canvas.drawCircle(c, r * (1.25 + 0.08 * t), Paint()
      ..shader = RadialGradient(colors: [AppColors.pink.withValues(alpha: 0.45), AppColors.violet.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r * 1.4)));
    // orb
    final orbRect = Rect.fromCircle(center: c, radius: r);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(orbRect),
      Path()..addOval(Rect.fromCircle(center: c.translate(r * 0.45, -r * 0.35), radius: r * 0.78)),
    );
    canvas.drawPath(crescent, Paint()..shader = AppColors.primaryGradient.createShader(orbRect));
    // spark
    final sp = c.translate(r * 0.55, -r * 0.45);
    final len = s * (0.11 + 0.02 * t);
    final star = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final p1 = sp + Offset(math.cos(a), math.sin(a)) * len;
      final p2 = sp + Offset(math.cos(a + math.pi / 4), math.sin(a + math.pi / 4)) * len * 0.22;
      if (i == 0) {
        star.moveTo(p1.dx, p1.dy);
      } else {
        star.lineTo(p1.dx, p1.dy);
      }
      star.lineTo(p2.dx, p2.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.t != t;
}
