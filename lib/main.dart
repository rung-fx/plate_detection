import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:plate_detection/views/crop_with_detect/result_page.dart';
import 'package:plate_detection/views/detect_no/no_plate.dart';
import 'package:plate_detection/views/crop/object_detection_page.dart';
import 'package:plate_detection/views/manual_crop/manual_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Plate Detection',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => const NoPlatePage());
                  },
                  child: Text('detect plate no'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => const ManualPage());
                  },
                  child: Text('manual crop'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => const PlateDetectionPage());
                  },
                  child: Text('crop plate'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Get.to(() => const ResultPage());
                  },
                  child: Text('detect plate + with plate no'),
                ),
              ],
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}
