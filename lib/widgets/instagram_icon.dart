import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 인스타그램 공식 그라데이션이 적용된 아이콘
class InstagramIcon extends StatelessWidget {
  final double size;

  const InstagramIcon({super.key, this.size = 20});

  static const _gradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF405DE6),
      Color(0xFF833AB4),
      Color(0xFFC13584),
      Color(0xFFE1306C),
      Color(0xFFFD1D1D),
      Color(0xFFF77737),
      Color(0xFFFCAF45),
      Color(0xFFFFDC80),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _gradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: FaIcon(FontAwesomeIcons.instagram, size: size, color: Colors.white),
    );
  }
}
