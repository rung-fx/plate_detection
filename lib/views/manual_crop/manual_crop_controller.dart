import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class ManualCropController extends GetxController {
  Rx<File?> imageFile = Rx<File?>(null);
  RxInt imageHeight = 0.obs;
  RxInt imageWidth = 0.obs;
  RxBool isLoading = false.obs;
  RxList<Map<String, dynamic>> recognitions = <Map<String, dynamic>>[].obs;

  RxString plateNo = "".obs;
  RxString province = "".obs;

  late Interpreter _interpreter;
  late List<String> _labels;
  final int inputSize = 640;

  List<String> plateNoTemp = [];

  @override
  void onInit() {
    super.onInit();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/plate_no_model/plate_no.tflite');
      log('Input Shape: ${_interpreter.getInputTensor(0).shape}');
      log('Output Shape: ${_interpreter.getOutputTensor(0).shape}');
      final labelsData =
          await rootBundle.loadString('assets/plate_no_model/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      log('Model loaded with ${_labels.length} labels');
    } catch (e) {
      log('Error loading model: $e');
    }
  }

  Future<void> pickImage(XFile? pickedFile) async {
    if (pickedFile == null) return;
    isLoading.value = true;
    recognitions.clear();
    plateNo.value = "";
    province.value = "";

    try {
      imageFile.value = File(pickedFile.path);
      await _runObjectDetection();
    } catch (e) {
      log('Error picking image: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _runObjectDetection() async {
    if (imageFile.value == null) return;

    try {
      final imageData = await imageFile.value!.readAsBytes();
      final image = img.decodeImage(imageData);
      if (image == null) {
        log('Failed to decode image');
        return;
      }

      imageHeight.value = image.height;
      imageWidth.value = image.width;

      final resizedImage = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.cubic,
      );

      final inputShape = _interpreter.getInputTensor(0).shape;
      List<List<List<List<double>>>> inputData;
      if (inputShape.length == 4 && inputShape[1] == 3) {
        inputData = _prepareInputNCHW(resizedImage);
      } else {
        inputData = _prepareInputNHWC(resizedImage);
      }

      final outputShape = _interpreter.getOutputTensor(0).shape;
      var outputData = _prepareOutputContainer(outputShape);

      log('Running inference...');
      _interpreter.run(inputData, outputData);

      var results = _processOutputs(
        outputData,
        outputShape,
        imageWidth.value,
        imageHeight.value,
      );

      // *** เพิ่ม OCR fallback เฉพาะ label '-' ***
      results = await _fixUnknownLabelsWithOCR(results, image);

      recognitions.assignAll(results);

      // ดึงบรรทัดออกมา (คงเดิม)
      final lines = extractLinesFromDetections(results);

      plateNo.value = lines.isNotEmpty ? lines[0] : "";
      province.value = lines.length > 1 ? lines[1] : "";

      log("plateNo: ${plateNo.value}");
      log("province: ${province.value}");
    } catch (e) {
      log('Error running object detection: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fixUnknownLabelsWithOCR(
      List<Map<String, dynamic>> detections, img.Image fullImage) async {
    plateNoTemp.clear();
    List<Map<String, dynamic>> updated = [];

    for (var det in detections) {
      if (det['label'] == '-') {
        final bbox = det['bbox'] as List<int>;
        var cropped = _cropImage(fullImage, bbox);
        cropped = _convertToBlackWhite(cropped, thresholdValue: 128);

        final tempPath =
            '${Directory.systemTemp.path}/ocr_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final croppedFile = File(tempPath)
          ..writeAsBytesSync(img.encodeJpg(cropped));
        plateNoTemp.add(tempPath);

        // OCR อ่านภาพแบบ single character
        final rawText = await FlutterTesseractOcr.extractText(
          croppedFile.path,
          language: "tha",
          args: {
            "psm": "10", // treat as single char
            "oem": "1"
          },
        );

        // กรองให้เหลือเฉพาะพยัญชนะไทย ก-ฮ
        final consonantOnly = rawText.replaceAll(RegExp(r'[^ก-ฮ]'), '');

        // เอาตัวแรกถ้ามีหลายตัว
        final cleanChar =
            consonantOnly.isNotEmpty ? consonantOnly.characters.first : '';

        log("OCR fallback raw:'$rawText' -> filtered:'$cleanChar'");

        det['label'] = cleanChar.isNotEmpty ? cleanChar : '-';
      }
      updated.add(det);
    }

    return updated;
  }

  img.Image _convertToBlackWhite(img.Image image, {int thresholdValue = 128}) {
    img.grayscale(image);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luma = img.getLuminance(pixel);
        final bwColor = (luma > thresholdValue)
            ? img.ColorUint8.rgb(255, 255, 255) // สีขาว
            : img.ColorUint8.rgb(0, 0, 0); // สีดำ

        image.setPixel(x, y, bwColor);
      }
    }
    return image;
  }

  img.Image _cropImage(img.Image source, List<int> bbox) {
    final x1 = bbox[0];
    final y1 = bbox[1];
    final x2 = bbox[2];
    final y2 = bbox[3];
    final w = (x2 - x1).clamp(1, source.width - x1);
    final h = (y2 - y1).clamp(1, source.height - y1);

    return img.copyCrop(source, x: x1, y: y1, width: w, height: h);
  }

  List<List<List<List<double>>>> _prepareInputNCHW(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        3,
        (c) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = image.getPixel(x, y);
            if (c == 0) return pixel.r / 255.0;
            if (c == 1) return pixel.g / 255.0;
            return pixel.b / 255.0;
          }),
        ),
      ),
    );
  }

  List<List<List<List<double>>>> _prepareInputNHWC(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );
  }

  dynamic _prepareOutputContainer(List<int> outputShape) {
    if (outputShape.length == 3) {
      return List.generate(
        outputShape[0],
        (_) => List.generate(
          outputShape[1],
          (_) => List<double>.filled(outputShape[2], 0.0),
        ),
      );
    }
    return [];
  }

  List<Map<String, dynamic>> _processOutputs(List<dynamic> outputData,
      List<int> outputShape, int sourceWidth, int sourceHeight) {
    const confidenceThreshold = 0.25;
    const iouThreshold = 0.45;
    List<Map<String, dynamic>> detections = [];

    try {
      if (outputShape.length == 3 && outputShape[1] == 84) {
        final numClasses = min(outputShape[1] - 4, 80);
        final numBoxes = outputShape[2];

        for (int i = 0; i < numBoxes; i++) {
          try {
            final x = outputData[0][0][i] as double;
            final y = outputData[0][1][i] as double;
            final w = outputData[0][2][i] as double;
            final h = outputData[0][3][i] as double;

            double maxConfidence = 0;
            int classId = 0;
            for (int c = 0; c < numClasses; c++) {
              final conf = outputData[0][4 + c][i] as double;
              if (conf > maxConfidence) {
                maxConfidence = conf;
                classId = c;
              }
            }

            if (maxConfidence > confidenceThreshold) {
              final label =
                  classId < _labels.length ? _labels[classId] : 'Unknown';
              if (label == 'Unknown') continue;

              double normX = x > 1.0 ? x / inputSize : x;
              double normY = y > 1.0 ? y / inputSize : y;
              double normW = w > 1.0 ? w / inputSize : w;
              double normH = h > 1.0 ? h / inputSize : h;

              final xmin = ((normX - normW / 2) * sourceWidth).round();
              final ymin = ((normY - normH / 2) * sourceHeight).round();
              final xmax = ((normX + normW / 2) * sourceWidth).round();
              final ymax = ((normY + normH / 2) * sourceHeight).round();

              detections.add({
                'bbox': [
                  xmin.clamp(0, sourceWidth - 1),
                  ymin.clamp(0, sourceHeight - 1),
                  xmax.clamp(0, sourceWidth - 1),
                  ymax.clamp(0, sourceHeight - 1)
                ],
                'confidence': maxConfidence,
                'class': classId,
                'label': label,
              });
            }
          } catch (e) {
            log('Error processing detection $i: $e');
          }
        }
      }
    } catch (e) {
      log('Error processing detections: $e');
    }

    final filtered = _nonMaxSuppression(detections, iouThreshold);
    final sorted = _sortDetectionsByReadingOrder(filtered);

    return sorted;
  }

  List<Map<String, dynamic>> _sortDetectionsByReadingOrder(
      List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return detections;

    const lineTolerance = 0.4;

    List<List<Map<String, dynamic>>> lines = [];

    for (var det in detections) {
      final bbox = det['bbox'] as List<int>;
      final ymin = bbox[1];
      final height = (bbox[3] - bbox[1]).toDouble();

      bool added = false;
      for (var line in lines) {
        final refBox = line.first['bbox'] as List<int>;
        final refYmin = refBox[1];
        final refHeight = (refBox[3] - refBox[1]).toDouble();

        if ((ymin - refYmin).abs() < refHeight * lineTolerance) {
          line.add(det);
          added = true;
          break;
        }
      }
      if (!added) {
        lines.add([det]);
      }
    }

    for (var line in lines) {
      line.sort((a, b) => (a['bbox'][0]).compareTo(b['bbox'][0]));
    }

    lines.sort((a, b) => (a.first['bbox'][1]).compareTo(b.first['bbox'][1]));

    return lines.expand((line) => line).toList();
  }

  List<String> extractLinesFromDetections(
      List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return [];

    const lineTolerance = 0.4;
    List<List<Map<String, dynamic>>> lines = [];

    for (var det in detections) {
      final bbox = det['bbox'] as List<int>;
      final ymin = bbox[1];
      final height = (bbox[3] - bbox[1]).toDouble();

      bool added = false;
      for (var line in lines) {
        final refBox = line.first['bbox'] as List<int>;
        final refYmin = refBox[1];
        final refHeight = (refBox[3] - refBox[1]).toDouble();

        if ((ymin - refYmin).abs() < refHeight * lineTolerance) {
          line.add(det);
          added = true;
          break;
        }
      }
      if (!added) {
        lines.add([det]);
      }
    }

    lines.sort((a, b) => (a.first['bbox'][1]).compareTo(b.first['bbox'][1]));

    List<String> resultLines = [];
    for (var line in lines) {
      line.sort((a, b) => (a['bbox'][0]).compareTo(b['bbox'][0]));
      final text = line.map((d) => d['label']).join('');
      resultLines.add(text);
    }

    return resultLines;
  }

  List<Map<String, dynamic>> _nonMaxSuppression(
      List<Map<String, dynamic>> detections, double iouThreshold) {
    detections.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    final List<Map<String, dynamic>> result = [];
    for (var det in detections) {
      bool keep = true;
      for (var kept in result) {
        if (_calculateIoU(
                List<int>.from(det['bbox']), List<int>.from(kept['bbox'])) >
            iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) result.add(det);
    }
    return result;
  }

  double _calculateIoU(List<int> box1, List<int> box2) {
    final int xmin = max(box1[0], box2[0]);
    final int ymin = max(box1[1], box2[1]);
    final int xmax = min(box1[2], box2[2]);
    final int ymax = min(box1[3], box2[3]);

    if (xmin >= xmax || ymin >= ymax) return 0.0;

    final intersection = (xmax - xmin) * (ymax - ymin);
    final area1 = (box1[2] - box1[0]) * (box1[3] - box1[1]);
    final area2 = (box2[2] - box2[0]) * (box2[3] - box2[1]);
    final union = area1 + area2 - intersection;
    return intersection / union;
  }

  @override
  void onClose() {
    _interpreter.close();
    super.onClose();
  }
}
