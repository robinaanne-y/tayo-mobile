import 'package:flutter/material.dart';

import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/app_colors.dart';

/// The welcome screen's hero art: a house with the family in its doorway,
/// two trees, and a little confetti, on a dotted blob. Drawn in code (no
/// image asset) so it follows the theme's colors in Light and Dark.
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: _HousePainter.designWidth / _HousePainter.designHeight,
        child: CustomPaint(
          painter: _HousePainter(
            primary: context.colors.primary,
            house: context.colors.surface,
          ),
        ),
      ),
    );
  }
}

class _HousePainter extends CustomPainter {
  _HousePainter({required this.primary, required this.house});

  static const designWidth = 260.0;
  static const designHeight = 200.0;

  final Color primary;
  final Color house;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is laid out on a 260x200 design grid, then scaled.
    final scale = size.width / designWidth;
    canvas.scale(scale);

    Paint fill(Color color) => Paint()..color = color;
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Dotted blob backdrop.
    final blob = RRect.fromRectAndRadius(
      const Rect.fromLTWH(32, 22, 196, 168),
      const Radius.circular(84),
    );
    canvas.drawRRect(blob, fill(primary.withValues(alpha: 0.08)));
    canvas.save();
    canvas.clipRRect(blob);
    final dot = fill(primary.withValues(alpha: 0.2));
    for (var x = 36.0; x < 228; x += 10) {
      for (var y = 26.0; y < 190; y += 10) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    // Soft hill behind the right tree, kept inside the blob.
    canvas.drawCircle(const Offset(200, 160), 26, fill(AppColors.mint.withValues(alpha: 0.18)));
    canvas.restore();

    // House body, windows, door.
    canvas.drawRect(const Rect.fromLTRB(86, 88, 174, 156), fill(house));
    final window = fill(AppColors.skyBlue.withValues(alpha: 0.55));
    canvas.drawRect(const Rect.fromLTWH(96, 98, 18, 15), window);
    canvas.drawRect(const Rect.fromLTWH(146, 98, 18, 15), window);
    canvas.drawRect(const Rect.fromLTRB(122, 118, 138, 156), fill(primary));

    // Roof.
    final roof = Path()
      ..moveTo(74, 96)
      ..lineTo(130, 46)
      ..lineTo(186, 96);
    canvas.drawPath(roof, stroke(AppColors.coral, 7));

    // The family in the doorway.
    canvas.drawCircle(const Offset(110, 145), 10, fill(AppColors.softYellow));
    canvas.drawCircle(const Offset(150, 146), 9, fill(AppColors.skyBlue));
    canvas.drawCircle(const Offset(130, 141), 12, fill(AppColors.coral));

    // Trees.
    canvas.drawLine(const Offset(66, 124), const Offset(66, 156), stroke(AppColors.lavender, 3));
    canvas.drawCircle(const Offset(66, 112), 15, fill(AppColors.lavender.withValues(alpha: 0.85)));
    canvas.drawLine(const Offset(194, 116), const Offset(194, 156), stroke(primary, 3));
    canvas.drawCircle(const Offset(194, 104), 13, fill(primary));

    // Ground.
    canvas.drawLine(
      const Offset(48, 157),
      const Offset(214, 157),
      stroke(primary.withValues(alpha: 0.3), 3),
    );

    // Confetti.
    canvas.drawCircle(const Offset(26, 50), 5, fill(AppColors.softYellow));
    canvas.drawCircle(const Offset(240, 82), 5, fill(AppColors.coral));
    canvas.save();
    canvas.translate(222, 22);
    canvas.rotate(-0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -3, 18, 6), const Radius.circular(3)),
      fill(primary),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HousePainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.house != house;
}
