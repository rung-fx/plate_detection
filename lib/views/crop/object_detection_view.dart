import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';

class ObjectDetectionView extends StatelessWidget {
  final File imageFile;
  final int imageHeight;
  final int imageWidth;
  final List<Map<String, dynamic>> recognitions;
  final double confidence;

  const ObjectDetectionView({
    super.key,
    required this.imageFile,
    required this.imageHeight,
    required this.imageWidth,
    required this.recognitions,
    this.confidence = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double availableHeight = constraints.maxHeight;

        // Calculate the image size to fit in the available space
        double displayWidth;
        double displayHeight;
        double leftPadding = 0;
        double topPadding = 0;

        // Calculate the aspect ratio of the image
        final double imageRatio = imageWidth / imageHeight;
        final double screenRatio = availableWidth / availableHeight;

        if (imageRatio > screenRatio) {
          // Image is wider than screen area, fit to width
          displayWidth = availableWidth;
          displayHeight = availableWidth / imageRatio;
          topPadding = (availableHeight - displayHeight) / 2;
        } else {
          // Image is taller than screen area, fit to height
          displayHeight = availableHeight;
          displayWidth = availableHeight * imageRatio;
          leftPadding = (availableWidth - displayWidth) / 2;
        }

        log('Image dimensions: $imageWidth x $imageHeight');
        log('Display dimensions: $displayWidth x $displayHeight');
        log('Scaling factors: X=${displayWidth / imageWidth}, Y=${displayHeight / imageHeight}');

        // Calculate scaling factors
        final double scaleX = displayWidth / imageWidth;
        final double scaleY = displayHeight / imageHeight;

        return Stack(
          children: [
            // Container for visualization
            Container(
              width: availableWidth,
              height: availableHeight,
              color: Colors.black12,
            ),

            // Image layer
            Positioned(
              left: leftPadding,
              top: topPadding,
              width: displayWidth,
              height: displayHeight,
              child: Image.file(
                imageFile,
                fit: BoxFit.fill,
              ),
            ),

            // Bounding boxes
            ...recognitions.map((recognition) {
              final List<int> bbox = List<int>.from(recognition['bbox']);
              final String label = recognition['label'] as String;
              final double score = recognition['confidence'] as double;
              final int classId = recognition['class'] as int;

              final color = Colors.primaries[classId % Colors.primaries.length];

              // Get coordinates from the bbox
              final int xMin = bbox[0];
              final int yMin = bbox[1];
              final int xMax = bbox[2];
              final int yMax = bbox[3];

              // Scale to display coordinates and add padding offset
              final double scaledXMin = (xMin * scaleX) + leftPadding;
              final double scaledYMin = (yMin * scaleY) + topPadding;
              final double scaledWidth = (xMax - xMin) * scaleX;
              final double scaledHeight = (yMax - yMin) * scaleY;

              // Debug
              log('Bound Box Original: [$xMin, $yMin, $xMax, $yMax]');
              log('Bound Box Scaled: [$scaledXMin, $scaledYMin, ${scaledXMin + scaledWidth}, ${scaledYMin + scaledHeight}]');

              return Positioned(
                left: scaledXMin,
                top: scaledYMin,
                width: scaledWidth,
                height: scaledHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        '$label ${(score * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
