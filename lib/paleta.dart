import 'package:flutter/material.dart';

class Paleta {
  static const azulClaro = Color(0xFF46DEE9);
  static const azul = Color(0xFF139FE3);
  static const verde = Color(0xFF58B88A);
  static const dourado = Color(0xFFF2B544);
  static const coral = Color(0xFFE87878);
  static const azulEscuro = Color(0xFF0876C8);
  static const vermelhoClaro = Color(0xFFF8CDCD);
  static const vermelhoEscuro = Color(0xFFA83E48);
  static const cores = [azulClaro, azul, verde, dourado, coral];
}

/// Ampulheta vetorial: vidro azul, areia dourada e estrutura azul escura.
class Ampulheta extends StatelessWidget {
  const Ampulheta({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 64, height: 80,
    child: CustomPaint(painter: _AmpulhetaPainter()),
  );
}

class _AmpulhetaPainter extends CustomPainter {
  const _AmpulhetaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 80);
    final vidro = Path()
      ..moveTo(16, 12)..lineTo(48, 12)
      ..cubicTo(48, 29, 40, 33, 35, 40)
      ..cubicTo(40, 47, 48, 51, 48, 68)
      ..lineTo(16, 68)
      ..cubicTo(16, 51, 24, 47, 29, 40)
      ..cubicTo(24, 33, 16, 29, 16, 12)..close();
    canvas.drawPath(vidro, Paint()..color = Paleta.azulClaro.withAlpha(45));
    canvas.drawPath(vidro, Paint()..color = Paleta.azul
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final areia = Paint()..color = Paleta.dourado;
    canvas.drawPath(Path()..moveTo(20, 23)..lineTo(44, 23)
      ..quadraticBezierTo(41, 31, 32, 37)
      ..quadraticBezierTo(23, 31, 20, 23)..close(), areia);
    canvas.drawPath(Path()..moveTo(19, 65)
      ..quadraticBezierTo(23, 57, 32, 52)
      ..quadraticBezierTo(41, 57, 45, 65)..close(), areia);
    canvas.drawLine(const Offset(32, 38), const Offset(32, 52),
      Paint()..color = Paleta.dourado..strokeWidth = 2..strokeCap = StrokeCap.round);
    final estrutura = Paint()..color = Paleta.azulEscuro;
    for (final y in [6.0, 68.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10, y, 44, 6),
        const Radius.circular(3)), estrutura);
    }
    canvas.drawLine(const Offset(21, 15), const Offset(23, 21),
      Paint()..color = Colors.white..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmpulhetaPainter oldDelegate) => false;
}
