import 'package:flutter/material.dart';

const ink = Color(0xFF1C1915);
const paper = Color(0xFFF3EDE2);
const pine = Color(0xFF23483E);
const clay = Color(0xFFC4654A);
const moss = Color(0xFF2F5D50);
const foam = Color(0xFFE7F0EC);
const night = Color(0xFF141614);
const ivory = Color(0xFFF4F1E8);
const sand = Color(0xFFC4B8A5);
const line = Color(0xFFD9D0C2);

ThemeData scriptureTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: paper,
    colorScheme: const ColorScheme.light(
      primary: pine,
      onPrimary: ivory,
      secondary: clay,
      onSecondary: ivory,
      surface: paper,
      onSurface: ink,
      error: clay,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: ivory, fontSize: 16),
    ),
  );
}
