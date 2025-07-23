import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/views/detect_no/no_plate_controller.dart';
import 'package:plate_detection/widgets/camera_gallery_bottom.dart';
import 'package:plate_detection/widgets/custom_loading.dart';
import 'package:plate_detection/widgets/text_font_style.dart';
import 'package:plate_detection/views/crop/object_detection_view.dart';
import 'package:plate_detection/constant/value_constant.dart';

class NoPlatePage extends StatelessWidget {
  const NoPlatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NoPlateController());

    return Scaffold(
      appBar: AppBar(
        title: Text('Detect Plate No'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const CustomLoading();
                }

                if (controller.imageFile.value == null) {
                  return InkWell(
                    onTap: controller.isLoading.value
                        ? null
                        : () async {
                      XFile? result = await Get.bottomSheet(
                          const SelectCameraGalleryBottomSheet());
                      if (result != null) controller.pickImage(result);
                    },
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined),
                          const SizedBox(height: margin),
                          TextFontStyle(
                            'upload photo'.tr,
                            size: fontSizeXL,
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ObjectDetectionView(
                  imageFile: controller.imageFile.value!,
                  imageHeight: controller.imageHeight.value,
                  imageWidth: controller.imageWidth.value,
                  recognitions: controller.recognitions,
                );
              }),
            ),

            Obx(() {
              if (controller.recognitions.isEmpty) return SizedBox.shrink();

              return Container(
                height: 200.0,
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: controller.recognitions.length,
                  itemBuilder: (context, index) {
                    final recognition = controller.recognitions[index];
                    return ListTile(
                      dense: true,
                      title: TextFontStyle(
                        '${recognition['label']}',
                        size: fontSizeM,
                        weight: FontWeight.bold,
                      ),
                      subtitle: TextFontStyle(
                        'Confidence: ${(recognition['confidence'] * 100).toStringAsFixed(1)}%',
                      ),
                      leading: Container(
                        width: 50.0,
                        height: 50.0,
                        color: Colors.primaries[
                        recognition['class'] % Colors.primaries.length],
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: Obx(() => Visibility(
        visible: controller.imageFile.value != null,
        child: FloatingActionButton(
          onPressed: controller.isLoading.value
              ? null
              : () async {
            XFile? result = await Get.bottomSheet(
                const SelectCameraGalleryBottomSheet());
            if (result != null) controller.pickImage(result);
          },
          backgroundColor: primaryColor,
          child: Icon(Icons.image_outlined),
        ),
      )),
    );
  }
}