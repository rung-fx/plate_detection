import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionController extends GetxController {
  bool isLoading = false;

  late Interpreter plateDetector;
  late Interpreter ocrDetector;
  late List<String> plateLabels;
  late List<String> ocrLabels;

  File? selectedImage;
  Map<String, dynamic>? bestPlate; // ป้ายใหญ่สุด
  Uint8List? croppedPlateBytes; // รูปป้ายที่ถูก crop
  List<Map<String, dynamic>> ocrBoxes = []; // กล่องตัวอักษร OCR
  String recognizedPlate = "";

  final int inputSize = 640;

  @override
  void onInit() {
    super.onInit();
    _loadModels();
  }

  Future<void> _loadModels() async {
    log("Loading models...");
    plateDetector = await Interpreter.fromAsset('assets/plate_model/plate.tflite');
    ocrDetector = await Interpreter.fromAsset('assets/plate_no_model/plate_no.tflite');

    plateLabels = (await rootBundle.loadString('assets/plate_model/labels.txt'))
        .split('\n')
        .where((s) => s.isNotEmpty)
        .toList();

    ocrLabels = (await rootBundle.loadString('assets/plate_no_model/labels.txt'))
        .split('\n')
        .where((s) => s.isNotEmpty)
        .toList();

    log("Models loaded: plate=${plateLabels.length}, ocr=${ocrLabels.length}");
  }

  Future<void> pickAndDetect(XFile file) async {
    selectedImage = File(file.path);
    isLoading = true;

    // เคลียร์ค่าก่อน detect ใหม่
    recognizedPlate = "";
    ocrBoxes.clear();
    bestPlate = null;
    croppedPlateBytes = null;

    update();

    await _detectPlateThenOCR();

    isLoading = false;
    update();
  }

  Future<void> _detectPlateThenOCR() async {
    final rawBytes = await selectedImage!.readAsBytes();
    final original = img.decodeImage(rawBytes);
    if (original == null) return;

    // Detect ป้ายใหญ่ (threshold ต่ำหน่อยให้จับได้ง่าย)
    final detections = await _runYOLO(
      plateDetector,
      original.width,
      original.height,
      original,
      confThreshold: 0.3,
    );
    if (detections.isEmpty) {
      log("No plate detected");
      return;
    }

    detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    bestPlate = detections.first;

    // Crop ป้ายใหญ่
    final bbox = bestPlate!['bbox'] as List<int>;
    final cropped = img.copyCrop(
      original,
      x: bbox[0],
      y: bbox[1],
      width: bbox[2] - bbox[0],
      height: bbox[3] - bbox[1],
    );

    // เก็บภาพที่ crop แล้วให้ UI แสดง
    croppedPlateBytes = Uint8List.fromList(img.encodeJpg(cropped));

    // Resize ให้ตรง input ของ OCR
    final scaled = img.copyResize(cropped, width: 640, height: 640, interpolation: img.Interpolation.linear);

    // OCR detect character (ใช้ threshold สูงกว่า + NMS)
    var ocrDetections = await _runYOLO(
      ocrDetector,
      scaled.width,
      scaled.height,
      scaled,
      confThreshold: 0.4,
    );

    // กรอง OCR box ซ้ำด้วย NMS
    ocrDetections = _nonMaxSuppression(ocrDetections, 0.3);

    // เก็บ OCR boxes ให้ UI วาด Bounding Box
    ocrBoxes = ocrDetections;

    // Sort ตัวอักษรจากซ้ายไปขวา
    ocrBoxes.sort((a, b) => (a['bbox'][0] as int).compareTo(b['bbox'][0] as int));

    // สร้างข้อความจาก OCR
    final sb = StringBuffer();
    for (var box in ocrBoxes) {
      final cls = box['class'] as int;
      if (cls >= 0 && cls < ocrLabels.length) {
        sb.write(ocrLabels[cls]);
      }
    }
    recognizedPlate = sb.toString();

    log("OCR recognized: $recognizedPlate");
  }

  Future<List<Map<String, dynamic>>> _runYOLO(
      Interpreter model,
      int origW,
      int origH,
      img.Image image, {
        double confThreshold = 0.3,
      }) async {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // prepare input NHWC
    final input = List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          },
        ),
      ),
    );

    final outShape = model.getOutputTensor(0).shape;
    final out = List.generate(
      outShape[0],
          (_) => List.generate(outShape[1], (_) => List<double>.filled(outShape[2], 0.0)),
    );

    model.run(input, out);

    return _parseYOLOOutput(out, outShape, origW, origH, confThreshold);
  }

  List<Map<String, dynamic>> _parseYOLOOutput(
      List<dynamic> out,
      List<int> outShape,
      int origW,
      int origH,
      double confTh,
      ) {
    List<Map<String, dynamic>> boxes = [];

    if (outShape[1] == 5) {
      // YOLO single-class
      final numBoxes = outShape[2];
      for (int i = 0; i < numBoxes; i++) {
        final x = out[0][0][i] as double;
        final y = out[0][1][i] as double;
        final w = out[0][2][i] as double;
        final h = out[0][3][i] as double;
        final conf = out[0][4][i] as double;
        if (conf > confTh) {
          final xmin = ((x - w / 2) * origW).clamp(0, origW - 1);
          final ymin = ((y - h / 2) * origH).clamp(0, origH - 1);
          final xmax = ((x + w / 2) * origW).clamp(0, origW - 1);
          final ymax = ((y + h / 2) * origH).clamp(0, origH - 1);
          boxes.add({
            'bbox': [xmin.round(), ymin.round(), xmax.round(), ymax.round()],
            'confidence': conf,
            'class': 0
          });
        }
      }
    } else {
      // YOLO multi-class [1,8400,84]
      final numBoxes = outShape[1];
      final numCls = outShape[2] - 4;
      for (int i = 0; i < numBoxes; i++) {
        final x = out[0][i][0] as double;
        final y = out[0][i][1] as double;
        final w = out[0][i][2] as double;
        final h = out[0][i][3] as double;

        double bestScore = 0;
        int bestCls = -1;
        for (int c = 0; c < numCls; c++) {
          final score = out[0][i][4 + c] as double;
          if (score > bestScore) {
            bestScore = score;
            bestCls = c;
          }
        }

        if (bestScore > confTh) {
          final xmin = ((x - w / 2) * origW).clamp(0, origW - 1);
          final ymin = ((y - h / 2) * origH).clamp(0, origH - 1);
          final xmax = ((x + w / 2) * origW).clamp(0, origW - 1);
          final ymax = ((y + h / 2) * origH).clamp(0, origH - 1);

          boxes.add({
            'bbox': [xmin.round(), ymin.round(), xmax.round(), ymax.round()],
            'confidence': bestScore,
            'class': bestCls,
          });
        }
      }
    }

    return boxes;
  }

  /// NMS ลบกล่อง OCR ซ้ำซ้อน
  List<Map<String, dynamic>> _nonMaxSuppression(List<Map<String, dynamic>> boxes, double iouThreshold) {
    boxes.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    final result = <Map<String, dynamic>>[];

    while (boxes.isNotEmpty) {
      final best = boxes.removeAt(0);
      result.add(best);

      boxes.removeWhere((box) {
        return _calculateIoU(best['bbox'], box['bbox']) > iouThreshold;
      });
    }
    return result;
  }

  double _calculateIoU(List bboxA, List bboxB) {
    final double xA = max<double>((bboxA[0] as num).toDouble(), (bboxB[0] as num).toDouble());
    final double yA = max<double>((bboxA[1] as num).toDouble(), (bboxB[1] as num).toDouble());
    final double xB = min<double>((bboxA[2] as num).toDouble(), (bboxB[2] as num).toDouble());
    final double yB = min<double>((bboxA[3] as num).toDouble(), (bboxB[3] as num).toDouble());

    final double interW = max<double>(0.0, xB - xA);
    final double interH = max<double>(0.0, yB - yA);
    final double interArea = interW * interH;

    final double boxAArea =
        ((bboxA[2] as num) - (bboxA[0] as num)).toDouble() * ((bboxA[3] as num) - (bboxA[1] as num)).toDouble();
    final double boxBArea =
        ((bboxB[2] as num) - (bboxB[0] as num)).toDouble() * ((bboxB[3] as num) - (bboxB[1] as num)).toDouble();

    final double unionArea = boxAArea + boxBArea - interArea;
    return unionArea > 0 ? interArea / unionArea : 0.0;
  }

  @override
  void onClose() {
    plateDetector.close();
    ocrDetector.close();
    super.onClose();
  }
}