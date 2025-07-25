import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/views/crop/object_detection_controller.dart';
import 'package:plate_detection/widgets/camera_gallery_bottom.dart';

class PlateDetectionPage extends StatelessWidget {
  const PlateDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PlateDetectionController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Plate"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GetBuilder<PlateDetectionController>(
          builder: (c) {
            if (c.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            // ยังไม่ได้เลือกรูป
            if (c.selectedImage == null) {
              return _buildUploadArea(c);
            }

            // แสดงผลหลัง detect
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  /// ภาพต้นฉบับพร้อมกรอบ
                  Stack(
                    children: [
                      Image.file(
                        c.selectedImage!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),

                      if (c.bestPlate != null)
                        Positioned(
                          left: (c.bestPlate!['bbox'][0] as int).toDouble(),
                          top: (c.bestPlate!['bbox'][1] as int).toDouble(),
                          width: ((c.bestPlate!['bbox'][2] as int) -
                              (c.bestPlate!['bbox'][0] as int))
                              .toDouble(),
                          height: ((c.bestPlate!['bbox'][3] as int) -
                              (c.bestPlate!['bbox'][1] as int))
                              .toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                color: Colors.red.withOpacity(0.6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(
                                  "${c.bestPlate!['label']} ${(c.bestPlate!['confidence'] * 100).toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ถ้ามี bbox → โชว์ข้อมูลและ crop
                  if (c.bestPlate != null) ...[
                    Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Detected Plate",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Label: ${c.bestPlate!['label']}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              "Confidence: ${(c.bestPlate!['confidence'] * 100).toStringAsFixed(1)}%",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              "BBox: ${c.bestPlate!['bbox']}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FutureBuilder<Uint8List?>(
                      future: _cropPlate(c.selectedImage!.path, c.bestPlate!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return const Text("Failed to crop plate");
                        }
                        return Column(
                          children: [
                            const Text(
                              "Cropped Plate",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Image.memory(
                              snapshot.data!,
                              width: 250,
                              fit: BoxFit.contain,
                            ),
                          ],
                        );
                      },
                    ),
                  ] else
                    const Text(
                      "No plate detected",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () async {
                      XFile? result = await Get.bottomSheet(
                        const SelectCameraGalleryBottomSheet(),
                      );
                      if (result != null) c.pickAndDetect(result);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Choose another image"),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadArea(PlateDetectionController c) {
    return Center(
      child: InkWell(
        onTap: () async {
          XFile? result =
          await Get.bottomSheet(const SelectCameraGalleryBottomSheet());
          if (result != null) c.pickAndDetect(result);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "Tap to upload a car image",
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  /// ฟังก์ชัน crop ป้ายทะเบียนออกมา
  Future<Uint8List?> _cropPlate(String imagePath, Map<String, dynamic> plate) async {
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
      return Uint8List.fromList(img.encodeJpg(cropped));
    } catch (e) {
      print("Crop error: $e");
      return null;
    }
  }
}