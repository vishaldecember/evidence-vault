import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const appTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: AppColors.navy,
    letterSpacing: -0.5,
  );

  static const pageTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.navy,
    letterSpacing: -0.4,
  );

  /// Home hero and workspace screen identity.
  static const heroTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.onCanvas,
    letterSpacing: -0.6,
    height: 1.22,
  );

  static const heroSubtitle = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.onCanvasSecondary,
    letterSpacing: 0.1,
  );

  /// Emphasis within cards — evidence type, context labels.
  static const emphasisLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.navy,
  );

  static const heading = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: AppColors.navy,
    letterSpacing: -0.35,
    height: 1.25,
  );

  static const body = TextStyle(
    fontSize: 16,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  static const bodySmall = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: AppColors.textMuted,
  );

  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.onPrimary,
    letterSpacing: -0.2,
  );

  static const label = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.navy,
  );

  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const link = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const dividerLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );

  static const socialButton = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const signInPrompt = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
  );

  static const strengthLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
