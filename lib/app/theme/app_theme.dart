import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'PinTayoSans',
  scaffoldBackgroundColor: AppColors.cream,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.emerald,
    primary: AppColors.emerald,
    surface: AppColors.cream,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: AppColors.navy,
    displayColor: AppColors.navy,
    fontFamily: 'PinTayoSans',
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.cream,
    foregroundColor: AppColors.navy,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFDEE6DF)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.mint,
  ),
);
