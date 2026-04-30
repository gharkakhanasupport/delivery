import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Animated number counter widget
/// Smoothly counts up from 0 to target value on load
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.decimals = 0,
  });

  /// Currency counter with ₹ prefix
  factory AnimatedCounter.currency({
    Key? key,
    required double value,
    TextStyle? style,
    int decimals = 0,
  }) {
    return AnimatedCounter(
      key: key,
      value: value,
      prefix: '₹',
      style: style,
      decimals: decimals,
    );
  }

  /// Integer counter (deliveries count, etc.)
  factory AnimatedCounter.integer({
    Key? key,
    required int value,
    String suffix = '',
    TextStyle? style,
  }) {
    return AnimatedCounter(
      key: key,
      value: value.toDouble(),
      suffix: suffix,
      style: style,
      decimals: 0,
    );
  }

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppConstants.curveEnter,
      ),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: AppConstants.curveEnter,
        ),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (widget.decimals == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(widget.decimals);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_formatNumber(_animation.value)}${widget.suffix}',
          style: widget.style ?? Theme.of(context).textTheme.headlineLarge,
        );
      },
    );
  }
}
