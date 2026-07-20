import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const appTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.navy,
  );

  static const screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.navy,
  );

  static const heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.navy,
  );

  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
}