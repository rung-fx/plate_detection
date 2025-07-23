import 'package:flutter/material.dart';
import 'package:plate_detection/constant/value_constant.dart';
import 'package:plate_detection/widgets/text_font_style.dart';

class CustomLoading extends StatelessWidget {
  const CustomLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(30.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: marginX2),
              TextFontStyle(
                'กำลังโหลด',
                color: Colors.black,
                weight: FontWeight.bold,
                size: fontSizeM,
              ),
            ],
          ),
        ),
      ),
    );
  }
}