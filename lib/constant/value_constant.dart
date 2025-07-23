import 'package:flutter/material.dart';

// font
const double fontSizeS = 12.0;
const double fontSizeM = 14.0;
const double fontSizeL = 16.0;
const double fontSizeXL = 18.0;
const double fontSizeXXL = 20.0;
const double fontListViewButton = 24.0;
const double fontAppbar = 28.0;

// color
const Color primaryColor = Color.fromRGBO(61, 153, 112, 1);
const Color secondaryColor = Color.fromRGBO(167, 211, 196, 1);

const Color primaryDark = Color.fromRGBO(33, 33, 33, 1);
const Color secondaryDark = Color.fromRGBO(42, 42, 42, 1);

// padding
const double margin = 8.0;
const double marginX2 = 16.0;

// shadow
List<BoxShadow> customBoxShadow = [
  BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 1.0,
    blurRadius: 5.0,
    offset: const Offset(1.0, 1.0),
  )
];