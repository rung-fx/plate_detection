import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/constant/value_constant.dart';
import 'package:plate_detection/utils/extension.dart';
import 'package:plate_detection/views/crop/object_detection_controller.dart';
import 'package:plate_detection/views/crop/object_detection_view.dart';
import 'package:plate_detection/views/manual_crop/manual_crop_controller.dart';
import 'package:plate_detection/widgets/camera_gallery_bottom.dart';
import 'package:image/image.dart' as img;
import 'package:plate_detection/widgets/custom_loading.dart';

class AutoCropPage extends StatefulWidget {
  const AutoCropPage({super.key});

  @override
  State<AutoCropPage> createState() => _AutoCropPageState();
}

class _AutoCropPageState extends State<AutoCropPage> {
  final PlateDetectionController _plateDetectionController =
      Get.put(PlateDetectionController());
  final ManualCropController _manualCropController =
      Get.put(ManualCropController());

  Uint8List? _imageCropUint8List;
  File? _imageCrop;

  var isLoading = false.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจจับป้ายทะเบียน'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    XFile? result = await Get.bottomSheet(
                      const SelectCameraGalleryBottomSheet(),
                    );

                    if (result != null) {
                      isLoading.value = true;
                      _plateDetectionController.selectedImage = null;
                      _imageCrop = null;
                      _manualCropController.plateNo.value = '';
                      _manualCropController.province.value = '';

                      await _plateDetectionController.pickAndDetect(result);

                      if (_plateDetectionController.bestPlate != null) {
                        final croppedBytes = await _cropPlate(
                          _plateDetectionController.selectedImage!.path,
                          _plateDetectionController.bestPlate!,
                        );

                        if (croppedBytes != null && _imageCrop != null) {
                          await _manualCropController.onlyDetect(_imageCrop);
                        }
                      }

                      isLoading.value = false;
                      setState(() {});
                    }
                  },
                  child: const Text(
                    'อัพโหลดรูปภาพ',
                    style: TextStyle(
                      color: Colors.black,
                    ),
                  ),
                ),
                _plateDetectionController.selectedImage != null
                    ? Expanded(
                        child: Image.file(
                          _plateDetectionController.selectedImage!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const SizedBox(),
                const SizedBox(height: marginX2),
                (_plateDetectionController.bestPlate != null &&
                        _imageCropUint8List != null)
                    ? Image.memory(
                        _imageCropUint8List!,
                        fit: BoxFit.contain,
                        height: 100.0,
                      )
                    : const SizedBox(),
                Expanded(
                  child: Obx(() {
                    if (_manualCropController.isLoading.value) {
                      return const CustomLoading();
                    }

                    if (_imageCrop == null ||
                        _manualCropController.imageWidth.value == 0 ||
                        _manualCropController.imageHeight.value == 0) {
                      return const SizedBox();
                    }

                    return ObjectDetectionView(
                      imageFile: _imageCrop!,
                      imageHeight: _manualCropController.imageHeight.value,
                      imageWidth: _manualCropController.imageWidth.value,
                      recognitions: _manualCropController.recognitions,
                    );
                  }),
                ),
                Container(
                  width: Get.width,
                  padding: EdgeInsets.symmetric(
                    horizontal: marginX2,
                    vertical: margin,
                  ),
                  margin: EdgeInsets.all(marginX2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ผลการตรวจจับป้ายทะเบียน',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      Text(
                        "เลขป้ายทะเบียน: ${_manualCropController.plateNo.value != '' ? _manualCropController.plateNo.value : '-'}",
                        style: TextStyle(fontSize: 16.0),
                      ),
                      Text(
                        "จังหวัด: ${_manualCropController.province.value != '' ? _manualCropController.province.value.provinceAbbr() : '-'}",
                        style: TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _loading(),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _cropPlate(
    String imagePath,
    Map<String, dynamic> plate,
  ) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      final bbox = plate['bbox'] as List<int>;
      final x = bbox[0];
      final y = bbox[1];
      final w = bbox[2] - bbox[0];
      final h = bbox[3] - bbox[1];

      if (w <= 0 || h <= 0) return null;

      final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

      _imageCropUint8List = Uint8List.fromList(img.encodeJpg(cropped));
      _imageCrop = await saveUint8ListToFile(
          _imageCropUint8List!, 'plate_${DateTime.now().hashCode}.jpg');

      return _imageCropUint8List;
    } catch (e) {
      print("Crop error: $e");
      return null;
    }
  }

  Future<File> saveUint8ListToFile(Uint8List bytes, String filename) async {
    final dir = Directory.systemTemp;
    final filePath = '${dir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  _loading() {
    return Obx(() {
      return Visibility(
        visible: isLoading.value,
        child: const CustomLoading(),
      );
    });
  }
}
