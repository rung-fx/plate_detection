import 'package:flutter/material.dart';
import 'package:freewill_fx_widgets/value_constant.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/widgets/text_font_style.dart';

class SelectCameraGalleryBottomSheet extends StatelessWidget {
  final double? imageHeight;
  final double? imageWidth;
  final int? imageQuality;

  const SelectCameraGalleryBottomSheet({
    super.key,
    this.imageHeight,
    this.imageWidth,
    this.imageQuality,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(
              onTap: () async {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  maxHeight: imageHeight,
                  maxWidth: imageWidth,
                  imageQuality: imageQuality,
                );

                Get.back(result: file);
              },
              icon: Icons.camera_alt_rounded,
              title: 'camera'.tr,
            ),
            _card(
              onTap: () async {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxHeight: imageHeight,
                  maxWidth: imageWidth,
                  imageQuality: imageQuality,
                );

                Get.back(result: file);
              },
              icon: Icons.photo,
              title: 'gallery'.tr,
            ),
          ],
        ),
      ),
    );
  }

  _card({
    required Function() onTap,
    required IconData icon,
    required String title,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: TextFontStyle(
        title,
        size: fontSizeM,
      ),
    );
  }
}