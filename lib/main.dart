import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:plate_detection/views/auto_crop_and_detect/auto_crop_page.dart';
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
      theme: ThemeData(
        fontFamily: GoogleFonts.kanit().fontFamily,
      ),
      home: AutoCropPage(),
      // child: SizedBox.expand(
      //   child: Column(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: [
      //       ElevatedButton(
      //         onPressed: () {
      //           Get.to(() => const NoPlatePage());
      //         },
      //         child: Text('detect plate no'),
      //       ),
      //       ElevatedButton(
      //         onPressed: () {
      //           Get.to(() => const ManualPage());
      //         },
      //         child: Text('manual crop'),
      //       ),
      //       ElevatedButton(
      //         onPressed: () {
      //           Get.to(() => const PlateDetectionPage());
      //         },
      //         child: Text('crop plate'),
      //       ),
      //       ElevatedButton(
      //         onPressed: () {
      //           Get.to(() => const ResultPage());
      //         },
      //         child: Text('detect plate + with plate no'),
      //       ),
      //       ElevatedButton(
      //         onPressed: () {
      //           Get.to(() => AutoCropPage());
      //         },
      //         child: Text('auto crop'),
      //       ),
      //     ],
      //   ),
      // ),
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
