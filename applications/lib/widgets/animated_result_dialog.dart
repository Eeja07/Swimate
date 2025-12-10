import 'package:flutter/material.dart';

class AnimatedResultDialog extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String message;
  final VoidCallback? onClose;

  const AnimatedResultDialog({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    this.onClose,
  });

  @override
  State<AnimatedResultDialog> createState() => _AnimatedResultDialogState();

  static Future<void> show({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    VoidCallback? onClose,
    Duration autoCloseDuration = const Duration(seconds: 2),
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => AnimatedResultDialog(
        isSuccess: isSuccess,
        title: title,
        message: message,
        onClose: onClose,
      ),
    );

    // Auto close setelah durasi tertentu
    if (context.mounted) {
      await Future.delayed(autoCloseDuration);
      if (context.mounted) {
        Navigator.of(context).pop();
        onClose?.call();
      }
    }
  }
}

class _AnimatedResultDialogState extends State<AnimatedResultDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _iconController;
  late AnimationController _checkController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation untuk dialog
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Icon scale animation
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconScaleAnimation = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    // Check/Cross draw animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    );

    // Mulai animasi
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _iconController.forward();
        _checkController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _iconController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isSuccess 
        ? const Color(0xFF4CAF50) // Green untuk success
        : const Color(0xFFE53935); // Red untuk error

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon
              ScaleTransition(
                scale: _iconScaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.15),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: widget.isSuccess
                      ? AnimatedCheckIcon(
                          animation: _checkAnimation,
                          color: primaryColor,
                        )
                      : AnimatedCrossIcon(
                          animation: _checkAnimation,
                          color: primaryColor,
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                widget.title,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Close button (optional)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onClose?.call();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated Check Icon (Centang)
class AnimatedCheckIcon extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const AnimatedCheckIcon({
    super.key,
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: CheckPainter(
            progress: animation.value,
            color: color,
          ),
        );
      },
    );
  }
}

class CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Titik awal (kiri bawah check)
    final startPoint = Offset(size.width * 0.25, size.height * 0.5);
    // Titik tengah (tengah bawah check)
    final midPoint = Offset(size.width * 0.45, size.height * 0.65);
    // Titik akhir (kanan atas check)
    final endPoint = Offset(size.width * 0.75, size.height * 0.35);

    if (progress < 0.5) {
      // Gambar garis pertama (kiri ke tengah)
      final currentProgress = progress * 2;
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(
        startPoint.dx + (midPoint.dx - startPoint.dx) * currentProgress,
        startPoint.dy + (midPoint.dy - startPoint.dy) * currentProgress,
      );
    } else {
      // Gambar garis lengkap pertama
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(midPoint.dx, midPoint.dy);
      
      // Gambar garis kedua (tengah ke kanan)
      final currentProgress = (progress - 0.5) * 2;
      path.lineTo(
        midPoint.dx + (endPoint.dx - midPoint.dx) * currentProgress,
        midPoint.dy + (endPoint.dy - midPoint.dy) * currentProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Animated Cross Icon (Silang)
class AnimatedCrossIcon extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const AnimatedCrossIcon({
    super.key,
    required this.animation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: CrossPainter(
            progress: animation.value,
            color: color,
          ),
        );
      },
    );
  }
}

class CrossPainter extends CustomPainter {
  final double progress;
  final Color color;

  CrossPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Titik untuk garis pertama (kiri atas ke kanan bawah)
    final line1Start = Offset(size.width * 0.3, size.height * 0.3);
    final line1End = Offset(size.width * 0.7, size.height * 0.7);
    
    // Titik untuk garis kedua (kanan atas ke kiri bawah)
    final line2Start = Offset(size.width * 0.7, size.height * 0.3);
    final line2End = Offset(size.width * 0.3, size.height * 0.7);

    if (progress < 0.5) {
      // Gambar garis pertama
      final currentProgress = progress * 2;
      path.moveTo(line1Start.dx, line1Start.dy);
      path.lineTo(
        line1Start.dx + (line1End.dx - line1Start.dx) * currentProgress,
        line1Start.dy + (line1End.dy - line1Start.dy) * currentProgress,
      );
    } else {
      // Gambar garis pertama lengkap
      path.moveTo(line1Start.dx, line1Start.dy);
      path.lineTo(line1End.dx, line1End.dy);
      
      // Gambar garis kedua
      final currentProgress = (progress - 0.5) * 2;
      path.moveTo(line2Start.dx, line2Start.dy);
      path.lineTo(
        line2Start.dx + (line2End.dx - line2Start.dx) * currentProgress,
        line2Start.dy + (line2End.dy - line2Start.dy) * currentProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CrossPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}