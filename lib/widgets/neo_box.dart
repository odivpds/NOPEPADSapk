import 'package:flutter/material.dart';

class NeoBox extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderWidth;
  final Offset shadowOffset;
  final Color shadowColor;
  final double? width;
  final double? height;

  const NeoBox({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFFFDE047),
    this.padding,
    this.margin,
    this.borderWidth = 4.0,
    this.shadowOffset = const Offset(6, 6),
    this.shadowColor = Colors.black,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.black, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: shadowOffset,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}
