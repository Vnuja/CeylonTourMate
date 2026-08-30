// lib/widgets/mic_button.dart
import 'package:flutter/material.dart';
import '../theme/ceylon_spice.dart';

class MicButton extends StatefulWidget {
  final bool isListening;
  final bool isDisabled;
  final VoidCallback onPressed;

  const MicButton({
    super.key,
    required this.isListening,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rippleAnim = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDisabled
        ? CeylonSpice.creamDarker
        : widget.isListening
            ? CeylonSpice.cinnamon
            : CeylonSpice.deepJungle;

    final borderColor = widget.isDisabled
        ? CeylonSpice.creamDarker
        : CeylonSpice.saffron;

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple ring
          if (widget.isListening)
            AnimatedBuilder(
              animation: _rippleAnim,
              builder: (_, __) => Transform.scale(
                scale: _rippleAnim.value,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CeylonSpice.saffron.withOpacity(
                      (1 - (_rippleAnim.value - 1) / 1.2).clamp(0, 0.4),
                    ),
                  ),
                ),
              ),
            ),

          // Button
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: widget.isListening ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: GestureDetector(
              onTap: widget.isDisabled ? null : widget.onPressed,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: widget.isDisabled
                      ? []
                      : [
                          BoxShadow(
                            color: bgColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: Text(
                    widget.isListening ? '⏹' : '🎤',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
