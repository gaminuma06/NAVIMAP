import 'package:flutter/material.dart';
import '../theme/design_system.dart';

class UserLocationMarker extends StatelessWidget {
  final double heading;

  const UserLocationMarker({
    super.key,
    required this.heading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60, // Aumentamos el área táctica
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aura de pulso táctico (Más grande y vibrante)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.5),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Container(
                width: 50 * value,
                height: 50 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3 * (1.5 - value)),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.5 * (1.5 - value)),
                    width: 2,
                  ),
                ),
              );
            },
            onEnd: () {}, // El loop se maneja por el builder si se requiere
          ),
          
          // Círculo central con sombra para profundidad
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          
          // Puntero de dirección (Brújula)
          Transform.rotate(
            angle: (heading * 3.14159 / 180),
            child: CustomPaint(
              size: const Size(25, 25),
              painter: DirectionPointerPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class DirectionPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    // Triángulo puntero (El pico del punto azul)
    path.moveTo(size.width / 2, -5); 
    path.lineTo(size.width / 2 - 5, 5);
    path.lineTo(size.width / 2 + 5, 5);
    path.close();

    // Sombra del puntero para visibilidad
    canvas.drawShadow(path, Colors.black, 2.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
