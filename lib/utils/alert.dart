import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:plate_detection/constant/value_constant.dart';
import 'package:plate_detection/widgets/custom_submit_button.dart';
import 'package:plate_detection/widgets/text_font_style.dart';

bool showingAlert = false;

showAlert(
    String title, {
      String? content,
      String? remark,
      Function()? onTap,
      bool? barrierDismissible,
    }) async {
  if (showingAlert) {
    return;
  }

  showingAlert = true;

  await Get.dialog(
    AlertDialog(
      title: TextFontStyle(
        title,
        align: TextAlign.center,
        size: fontSizeL,
        color: Colors.black,
      ),
      content: content != null
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFontStyle(
            content,
            align: TextAlign.center,
            size: fontSizeM,
          ),
          const SizedBox(height: margin),
          Visibility(
            visible: remark != null,
            child: TextFontStyle(
              remark ?? '',
              align: TextAlign.center,
              size: 10.0,
            ),
          ),
        ],
      )
          : null,
      actions: [
        CustomSubmitButton(
          buttonWidth: 100.0,
          onTap: () async {
            showingAlert = false;
            Get.back();

            if (onTap != null) {
              onTap();
            }
          },
          title: 'ตกลง',
          buttonColor: primaryColor,
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    ),
    barrierDismissible: barrierDismissible ?? false,
  );

  showingAlert = false;
}

showNoInternetAlert() {
  showAlert(
    'ไม่พบสัญญาณอินเตอร์เน็ต',
    content: 'กรุณาลองอีกครั้ง',
    onTap: () {
      Get.back();
    },
  );
}

showServerErrorDialog() {
  showAlert(
    'ระบบขัดข้อง',
    content: 'กรุณาลองอีกครั้ง',
    onTap: () {
      Get.back();
    },
  );
}

showConfirmAlert({
  required String title,
  required Function() onConfirm,
  required String confirmText,
  Function()? onCancel,
  required String cancelText,
  String? content,
  bool barrierDismissible = true,
}) async {
  if (showingAlert) {
    return;
  }

  showingAlert = true;

  bool? result = await Get.dialog(
    AlertDialog(
      title: TextFontStyle(
        title,
        align: TextAlign.center,
        size: fontSizeM,
        color: Colors.black,
      ),
      content: content != null
          ? TextFontStyle(
        content,
        align: TextAlign.center,
        size: fontSizeS,
      )
          : null,
      actions: [
        CustomSubmitButton(
          buttonWidth: 100.0,
          onTap: () async {
            showingAlert = false;
            Get.back();
          },
          title: cancelText,
          fontColor: primaryColor,
          buttonColor: Colors.transparent,
          borderColor: primaryColor,
        ),
        CustomSubmitButton(
          buttonWidth: 100.0,
          onTap: () async {
            showingAlert = false;
            Get.back(result: true);
            onConfirm();
          },
          title: confirmText,
          buttonColor: primaryColor,
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    ),
    barrierDismissible: barrierDismissible,
  );

  showingAlert = false;

  if (result == null && onCancel != null) {
    onCancel();
  }
}