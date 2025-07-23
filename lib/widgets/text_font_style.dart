import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plate_detection/constant/value_constant.dart';

class TextFontStyle extends StatelessWidget {
  final String data;
  final Color? color;
  final TextStyle? style;
  final double size;
  final FontWeight weight;
  final bool underline;
  final TextOverflow? overflow;
  final TextAlign align;

  const TextFontStyle(
      this.data, {
        super.key,
        this.color,
        this.style,
        this.size = fontSizeS,
        this.weight = FontWeight.normal,
        this.underline = false,
        this.overflow,
        this.align = TextAlign.left,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style ??
          TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            fontFamily: GoogleFonts.kanit().fontFamily,
            decoration: underline ? TextDecoration.underline : null,
            overflow: overflow,
          ),
      textAlign: align,
    );
  }
}