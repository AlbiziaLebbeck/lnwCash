import 'package:flutter/material.dart';

class AvatarImage extends StatelessWidget {
  const AvatarImage(this.name, {super.key, this.width = 100, this.height = 100, this.bgColor, this.borderWidth = 0, this.borderColor, this.trBackground = false, this.radius = 50});
  final String name;
  final double width;
  final double height;
  final double borderWidth;
  final Color? borderColor;
  final Color? bgColor;
  final bool trBackground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? Theme.of(context).cardColor, width: borderWidth), 
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black87.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(1, 1), // changes position of shadow
          ),
        ],
        image: DecorationImage(image: NetworkImage(name), fit: BoxFit.cover),
      ),
    );
  }

}