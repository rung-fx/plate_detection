import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plate_detection/views/crop_with_detect/detect_controller.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DetectionController());

    return Scaffold(
      appBar: AppBar(title: const Text("Plate Detection & OCR")),
      body: SafeArea(
        child: GetBuilder<DetectionController>(
          builder: (c) {
            if (c.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (c.selectedImage == null) {
              return _buildInitialSelect(c);
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  /// ภาพต้นฉบับ + Bounding Box ของป้ายทะเบียน
                  if (c.bestPlate != null)
                    Column(
                      children: [
                        const Text(
                          "Detected Plate Area",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Image.file(c.selectedImage!),
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
                                    color: Colors.red.withOpacity(0.7),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      "Plate ${(c.bestPlate!['confidence'] * 100).toStringAsFixed(1)}%",
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  /// Cropped Plate + OCR Bounding Box
                  if (c.croppedPlateBytes != null)
                    Column(
                      children: [
                        const Text(
                          "Cropped Plate + OCR Detection",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        AspectRatio(
                          aspectRatio: 3 / 1,
                          child: Stack(
                            children: [
                              Image.memory(
                                c.croppedPlateBytes!,
                                fit: BoxFit.contain,
                              ),

                              /// Bounding Boxes ของตัวอักษร OCR
                              ...c.ocrBoxes.map((b) {
                                final bbox = b['bbox'] as List<int>;
                                final cls = b['class'] as int;
                                final conf = b['confidence'] as double;
                                final label = (cls >= 0 && cls < c.ocrLabels.length)
                                    ? c.ocrLabels[cls]
                                    : "?";

                                return Positioned(
                                  left: bbox[0].toDouble(),
                                  top: bbox[1].toDouble(),
                                  width: (bbox[2] - bbox[0]).toDouble(),
                                  height: (bbox[3] - bbox[1]).toDouble(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.greenAccent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Container(
                                        color: Colors.green.withOpacity(0.7),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3, vertical: 1),
                                        child: Text(
                                          "$label ${(conf * 100).toStringAsFixed(1)}%",
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  /// Recognized Plate Text
                  if (c.recognizedPlate.isNotEmpty)
                    Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              "Recognized Plate Number",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.recognizedPlate,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  /// ปุ่มเลือกภาพใหม่
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) c.pickAndDetect(picked);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Choose another image"),
                    ),
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

  /// เริ่มต้นให้เลือกภาพ
  Widget _buildInitialSelect(DetectionController c) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (picked != null) c.pickAndDetect(picked);
        },
        icon: const Icon(Icons.image_outlined),
        label: const Text("Choose image"),
      ),
    );
  }
}