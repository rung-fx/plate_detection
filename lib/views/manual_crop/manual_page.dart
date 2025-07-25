import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/utils/extension.dart';
import 'package:plate_detection/views/crop/object_detection_view.dart';
import 'package:plate_detection/views/manual_crop/manual_crop_controller.dart';
import 'package:plate_detection/widgets/camera_gallery_bottom.dart';
import 'package:plate_detection/widgets/custom_loading.dart';
import 'package:image/image.dart' as img;

class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  final controller = Get.put(ManualCropController());

  File? originalFile;
  File? imageFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SizedBox.expand(
          child: Obx(
            () => Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    XFile? result = await Get.bottomSheet(
                        const SelectCameraGalleryBottomSheet());

                    if (result == null) return;

                    final croppedImage = await ImageCropper().cropImage(
                      sourcePath: result.path,
                      uiSettings: [
                        AndroidUiSettings(
                          toolbarTitle: 'Crop Image',
                          toolbarColor: Colors.deepOrange,
                          toolbarWidgetColor: Colors.white,
                          initAspectRatio: CropAspectRatioPreset.original,
                          lockAspectRatio: false,
                        ),
                      ],
                    );

                    if (croppedImage == null) return;
                    imageFile = File(croppedImage.path);
                    originalFile = imageFile;

                    if (imageFile != null) {
                      controller.pickImage(XFile(imageFile!.path));
                    }

                    setState(() {});
                  },
                  child: Text('manual crop'),
                ),
                const SizedBox(height: 16.0),
                originalFile != null ? Image.file(originalFile!) : SizedBox(),
                const SizedBox(height: 16.0),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const CustomLoading();
                    }

                    if (imageFile == null) {
                      return SizedBox();
                    }

                    return ObjectDetectionView(
                      imageFile: imageFile!,
                      imageHeight: controller.imageHeight.value,
                      imageWidth: controller.imageWidth.value,
                      recognitions: controller.recognitions,
                    );
                  }),
                ),
                controller.plateNoTemp.isNotEmpty
                    ? Wrap(
                        children: controller.plateNoTemp
                            .map((e) => Image.file(File(e)))
                            .toList(),
                      )
                    : SizedBox(),
                const SizedBox(height: 16.0),
                Text(
                  'ผลการตรวจจับป้ายทะเบียน',
                  style: TextStyle(fontSize: 18.0),
                ),
                Text(
                  "Plate No: ${controller.plateNo.value}",
                  style: TextStyle(fontSize: 18.0),
                ),
                Text(
                  "Province: ${controller.province.value.provinceAbbr()}",
                  style: TextStyle(fontSize: 18.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
