import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PlateDetectionController extends GetxController {
  bool isLoading = false;
  bool isModelLoaded = false;

  late Interpreter interpreter;
  late List<String> labels;

  File? selectedImage;
  int? imageWidth;
  int? imageHeight;

  Map<String, dynamic>? bestPlate;

  final int inputSize = 640;

  @override
  void onInit() {
    super.onInit();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      log("Loading plate detection model...");
      interpreter = await Interpreter.fromAsset('assets/plate_model/plate.tflite');

      final labelsData =
      await rootBundle.loadString('assets/plate_model/labels.txt');
      labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();

      isModelLoaded = true;
      log("Model loaded successfully with ${labels.length} labels");
    } catch (e) {
      log("Failed to load model: $e");
    }
  }

  Future<void> pickAndDetect(XFile picked) async {
    if (!isModelLoaded) {
      log("Model not loaded yet");
      return;
    }

    isLoading = true;
    bestPlate = null;
    update();

    selectedImage = File(picked.path);
    await _detectPlate();

    isLoading = false;
    update();
  }

  Future<void> _detectPlate() async {
    if (selectedImage == null) return;

    final rawImage = await selectedImage!.readAsBytes();
    final decoded = img.decodeImage(rawImage);
    if (decoded == null) {
      log("Cannot decode image");
      return;
    }

    imageWidth = decoded.width;
    imageHeight = decoded.height;
    log("Original image: ${decoded.width}x${decoded.height}");

    // Resize ให้ตรง input
    final resized = img.copyResize(decoded, width: inputSize, height: inputSize);

    // เตรียม input
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    log("Input shape=$inputShape, Output shape=$outputShape");

    final inputData = _prepareInputNHWC(resized);
    final outputData = _allocateOutput(outputShape);

    log("Running YOLO...");
    interpreter.run(inputData, outputData);

    // Process YOLO output → detect boxes
    var detections = _processOutput(outputData, outputShape, decoded.width, decoded.height);

    // ทำ NMS
    detections = _nonMaxSuppression(detections, 0.45);

    if (detections.isNotEmpty) {
      // เอาเฉพาะ box ที่ conf สูงสุด
      detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
      bestPlate = detections.first;
      log("Best plate: $bestPlate");
    } else {
      log("No plate detected!");
    }
  }

  /// เตรียม output array
  List<dynamic> _allocateOutput(List<int> outputShape) {
    if (outputShape.length == 3) {
      return List.generate(
        outputShape[0],
            (_) => List.generate(
          outputShape[1],
              (_) => List<double>.filled(outputShape[2], 0.0),
        ),
      );
    }
    throw Exception("Unsupported output shape: $outputShape");
  }

  /// Convert image → NHWC float
  List<List<List<List<double>>>> _prepareInputNHWC(img.Image image) {
    return List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
  }

  /// Process YOLO output → bbox list
  List<Map<String, dynamic>> _processOutput(
      List<dynamic> outputData,
      List<int> outputShape,
      int sourceWidth,
      int sourceHeight,
      ) {
    const confidenceThreshold = 0.3;
    List<Map<String, dynamic>> detections = [];

    if (outputShape.length == 3 && outputShape[1] == 5) {
      // YOLO แบบ single-class: [1,5,8400]
      final numBoxes = outputShape[2];
      for (int i = 0; i < numBoxes; i++) {
        final x = outputData[0][0][i] as double;
        final y = outputData[0][1][i] as double;
        final w = outputData[0][2][i] as double;
        final h = outputData[0][3][i] as double;
        final conf = outputData[0][4][i] as double;

        if (conf > confidenceThreshold) {
          // เป็น normalized (0-1)
          final xmin = ((x - w / 2) * sourceWidth).clamp(0, sourceWidth - 1);
          final ymin = ((y - h / 2) * sourceHeight).clamp(0, sourceHeight - 1);
          final xmax = ((x + w / 2) * sourceWidth).clamp(0, sourceWidth - 1);
          final ymax = ((y + h / 2) * sourceHeight).clamp(0, sourceHeight - 1);

          detections.add({
            'bbox': [xmin.round(), ymin.round(), xmax.round(), ymax.round()],
            'confidence': conf,
            'label': labels.isNotEmpty ? labels.first : "plate",
          });
        }
      }
    } else if (outputShape.length == 3 && outputShape[2] >= 84) {
      // YOLO multi-class: [1,8400,84]
      final numBoxes = outputShape[1];
      final numClasses = outputShape[2] - 4;

      for (int i = 0; i < numBoxes; i++) {
        final x = outputData[0][i][0] as double;
        final y = outputData[0][i][1] as double;
        final w = outputData[0][i][2] as double;
        final h = outputData[0][i][3] as double;

        double bestConf = 0;
        int bestClass = 0;
        for (int c = 0; c < numClasses; c++) {
          final cScore = outputData[0][i][4 + c] as double;
          if (cScore > bestConf) {
            bestConf = cScore;
            bestClass = c;
          }
        }

        if (bestConf > confidenceThreshold) {
          final xmin = ((x - w / 2) * sourceWidth).clamp(0, sourceWidth - 1);
          final ymin = ((y - h / 2) * sourceHeight).clamp(0, sourceHeight - 1);
          final xmax = ((x + w / 2) * sourceWidth).clamp(0, sourceWidth - 1);
          final ymax = ((y + h / 2) * sourceHeight).clamp(0, sourceHeight - 1);

          detections.add({
            'bbox': [xmin.round(), ymin.round(), xmax.round(), ymax.round()],
            'confidence': bestConf,
            'label': (bestClass < labels.length)
                ? labels[bestClass]
                : "class_$bestClass",
          });
        }
      }
    }

    return detections;
  }

  /// Non-Max Suppression
  List<Map<String, dynamic>> _nonMaxSuppression(
      List<Map<String, dynamic>> boxes, double iouThreshold) {
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
    // แปลงให้เป็น double ก่อน
    final double xA = max<double>((bboxA[0] as num).toDouble(), (bboxB[0] as num).toDouble());
    final double yA = max<double>((bboxA[1] as num).toDouble(), (bboxB[1] as num).toDouble());
    final double xB = min<double>((bboxA[2] as num).toDouble(), (bboxB[2] as num).toDouble());
    final double yB = min<double>((bboxA[3] as num).toDouble(), (bboxB[3] as num).toDouble());

    final double interW = max<double>(0.0, xB - xA);
    final double interH = max<double>(0.0, yB - yA);
    final double interArea = interW * interH;

    final double boxAArea =
        ((bboxA[2] as num) - (bboxA[0] as num)).toDouble() *
            ((bboxA[3] as num) - (bboxA[1] as num)).toDouble();
    final double boxBArea =
        ((bboxB[2] as num) - (bboxB[0] as num)).toDouble() *
            ((bboxB[3] as num) - (bboxB[1] as num)).toDouble();

    final double unionArea = boxAArea + boxBArea - interArea;
    return unionArea > 0 ? interArea / unionArea : 0.0;
  }

  @override
  void onClose() {
    interpreter.close();
    super.onClose();
  }
}