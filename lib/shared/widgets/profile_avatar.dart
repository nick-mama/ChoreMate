import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final double size;

  const ProfileAvatar({super.key, this.imagePath, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.rectangle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath != null
          ? Image.asset(
              imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _defaultIcon(),
            )
          : _defaultIcon(),
    );
  }

  Widget _defaultIcon() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: size * 0.4, color: Colors.grey.shade600),
    );
  }
}
