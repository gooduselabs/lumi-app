import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Original procedurally drawn avatars ("Lumi blobs"). 24 variants, id a01..a24.
class LumiAvatar extends StatelessWidget {
  const LumiAvatar({super.key, required this.avatarId, this.size = 48, this.online, this.ring = false});

  final String? avatarId;
  final double size;
  final bool? online;
  final bool ring;

  static const ids = [
    'a01', 'a02', 'a03', 'a04', 'a05', 'a06', 'a07', 'a08', 'a09', 'a10', 'a11', 'a12',
    'a13', 'a14', 'a15', 'a16', 'a17', 'a18', 'a19', 'a20', 'a21', 'a22', 'a23', 'a24',
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (int.tryParse((avatarId ?? 'a01').substring(1)) ?? 1) - 1;
    Widget child = CustomPaint(size: Size.square(size), painter: _BlobPainter(idx.clamp(0, 23)));
    if (ring) {
      child = Container(
        padding: EdgeInsets.all(size * 0.045),
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
        child: Container(
          padding: EdgeInsets.all(size * 0.03),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
          child: child,
        ),
      );
    }
    if (online == null) return child;
    final dot = size * 0.26;
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(
        right: 0,
        bottom: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online! ? AppColors.mint : AppColors.textFaint,
            border: Border.all(color: AppColors.bg, width: math.max(2, size * 0.04)),
          ),
        ),
      ),
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.i);
  final int i;

  static const _bgs = [
    [Color(0xFF7C5CFF), Color(0xFFFF5CA8)], [Color(0xFF3D7BFF), Color(0xFF3DDCFF)],
    [Color(0xFFFF8A5C), Color(0xFFFF5CA8)], [Color(0xFF4BE3A4), Color(0xFF3DDCFF)],
    [Color(0xFFFFC75C), Color(0xFFFF8A5C)], [Color(0xFF9B5CFF), Color(0xFF3D7BFF)],
  ];
  static const _bodies = [
    Color(0xFFFFE3D3), Color(0xFFFFF3B0), Color(0xFFD7F5FF), Color(0xFFFFD6EC),
    Color(0xFFE2DBFF), Color(0xFFD5FBE8), Color(0xFFFFE0B8), Color(0xFFF1F1F6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final bg = _bgs[i % _bgs.length];
    final body = _bodies[(i * 5 + 3) % _bodies.length];
    final ears = (i ~/ 6) % 4; // 0 none,1 cat,2 bunny,3 antenna
    final eyes = (i * 7) % 3; // 0 dots,1 happy arcs,2 big shiny
    final mouth = (i * 3) % 3;

    // background disc
    final rect = Rect.fromCircle(center: c, radius: s / 2);
    canvas.drawCircle(c, s / 2, Paint()..shader = LinearGradient(colors: bg, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    // soft highlight (clipped to the disc)
    canvas.drawCircle(Offset(s * 0.3, s * 0.25), s * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.12));
    final bodyPaint = Paint()..color = body;

    // ears / accessories
    switch (ears) {
      case 1:
        for (final dx in [-1, 1]) {
          final p = Path()
            ..moveTo(c.dx + dx * s * 0.30, s * 0.44)
            ..lineTo(c.dx + dx * s * 0.27, s * 0.17)
            ..lineTo(c.dx + dx * s * 0.08, s * 0.33)
            ..close();
          canvas.drawPath(p, bodyPaint);
        }
      case 2:
        for (final dx in [-1, 1]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx + dx * s * 0.14, s * 0.2), width: s * 0.12, height: s * 0.32), Radius.circular(s)),
            bodyPaint,
          );
        }
      case 3:
        canvas.drawLine(Offset(c.dx, s * 0.34), Offset(c.dx + s * 0.06, s * 0.14), Paint()..color = body..strokeWidth = s * 0.03..strokeCap = StrokeCap.round);
        canvas.drawCircle(Offset(c.dx + s * 0.06, s * 0.13), s * 0.05, Paint()..color = AppColors.amber);
    }

    // body blob
    final blob = RRect.fromRectAndCorners(
      Rect.fromLTWH(s * 0.18, s * 0.3, s * 0.64, s * 0.85),
      topLeft: Radius.circular(s * 0.32), topRight: Radius.circular(s * 0.32),
      bottomLeft: Radius.circular(s * 0.1), bottomRight: Radius.circular(s * 0.1),
    );
    canvas.drawRRect(blob, bodyPaint);

    final ink = Paint()..color = const Color(0xFF2A1F45);
    final ey = s * 0.53;
    final ex = s * 0.12;
    switch (eyes) {
      case 0:
        canvas.drawCircle(Offset(c.dx - ex, ey), s * 0.04, ink);
        canvas.drawCircle(Offset(c.dx + ex, ey), s * 0.04, ink);
      case 1:
        final arc = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = s * 0.03..strokeCap = StrokeCap.round;
        for (final dx in [-ex, ex]) {
          canvas.drawArc(Rect.fromCenter(center: Offset(c.dx + dx, ey + s * 0.01), width: s * 0.1, height: s * 0.08), math.pi, math.pi, false, arc);
        }
      default:
        for (final dx in [-ex, ex]) {
          canvas.drawCircle(Offset(c.dx + dx, ey), s * 0.055, ink);
          canvas.drawCircle(Offset(c.dx + dx + s * 0.018, ey - s * 0.018), s * 0.018, Paint()..color = Colors.white);
        }
    }
    // blush
    final blush = Paint()..color = AppColors.pink.withValues(alpha: 0.35);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - s * 0.2, s * 0.62), width: s * 0.1, height: s * 0.06), blush);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + s * 0.2, s * 0.62), width: s * 0.1, height: s * 0.06), blush);
    // mouth
    final mp = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = s * 0.025..strokeCap = StrokeCap.round;
    switch (mouth) {
      case 0:
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, s * 0.62), width: s * 0.12, height: s * 0.08), 0, math.pi, false, mp);
      case 1:
        canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, s * 0.645), width: s * 0.06, height: s * 0.07), ink);
      default:
        final p = Path()
          ..moveTo(c.dx - s * 0.06, s * 0.63)
          ..quadraticBezierTo(c.dx - s * 0.03, s * 0.665, c.dx, s * 0.63)
          ..quadraticBezierTo(c.dx + s * 0.03, s * 0.665, c.dx + s * 0.06, s * 0.63);
        canvas.drawPath(p, mp);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.i != i;
}
