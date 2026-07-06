import 'package:flutter/material.dart';

// CustomPaint = ekta khali drawing board (A Widget je drawing er code ke show kore)
// CustomPainter = je drawing kore (A class je drawing er code likhe)
// Canvas = kagoj
// Paint = kolom/brush
// paint() = ekhane drawing er code likhi

class CustomPaintPracticeScreen extends StatelessWidget {
  const CustomPaintPracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Paint Practice'),
      ),
      body: Center(
        child: CustomPaint(
          size: const Size(300, 300),
          painter: MyFirstPainter(),
        ),
      ),
    );
  }
}

class MyFirstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // But Dart-e .. diye same object-er upor multiple property set kora jay. Eta ke bole cascade operator.
    // final paint = Paint()
    //   ..color = Colors.red
    //   ..strokeWidth = 5
    //   ..style = PaintingStyle.stroke;

    final paint = Paint();

    paint.color = Colors.blue;
    paint.strokeWidth = 5;
    paint.style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      80,
      paint,
    );
    // canvas.drawLine(
    //   Offset(size.width / 2, size.height / 2),
    //   Offset(size.width / 2, size.height / 2 - 80),
    //   paint,
    // );
    // canvas.drawLine(
    //   Offset(size.width / 2, size.height / 2),
    //   Offset(size.width / 2 + 80, size.height / 2),
    //   paint,
    // );
    // canvas.drawLine(
    //   Offset(size.width / 2, size.height / 2),
    //   Offset(size.width / 2 - 80, size.height / 2),
    //   paint,
    // );
  }

  @override
  bool shouldRepaint(covariant MyFirstPainter oldDelegate) {
    return false;
  }
}
