import 'package:flutter/material.dart';

/// App-wide constants for PDF Scanner
class AppConstants {
  // App Info
  static const String appName = 'PDF Scanner';

  // Colors - iOS-style color scheme
  static const Color primaryColor = Color(0xFFFF3B30); // Red (iOS Red)
  static const Color backgroundColor = Color(0xFFF5F5FA); // iOS Soft Gray
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color successColor = Color(0xFF34C759); // iOS Green
  static const Color errorColor = Color(0xFFFF3B30); // iOS Red

  // Edge Detection
  static const Color edgeDetectedColor = Color(0xFF34C759); // Green glow
  static const Color edgeNotDetectedColor = Color(0xFFFF9500); // Orange

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 18.0; // Rounded corners (15-20 range)
  static const double cardElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Auto-capture Settings
  static const Duration stabilityDuration = Duration(
    milliseconds: 1000,
  ); // 1 second stability as requested
  static const double minDocumentAreaRatio = 0.05; // 5% area
  static const double stabilityThreshold = 50.0; // Stricter threshold
  static const int stabilityCheckInterval = 100; // ms

  // Storage
  static const String scansDirectoryName = 'scans';
  static const String thumbnailsDirectoryName = 'thumbnails';
  static const String scansMetadataFileName = 'scans_metadata.json';

  // Image Processing
  static const int thumbnailSize = 300;
  static const int maxImageWidth = 2000;
  static const int maxImageHeight = 3000;
}

/// Text Styles
class AppTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppConstants.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppConstants.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppConstants.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppConstants.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle emptyStateTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppConstants.textSecondary,
  );

  static const TextStyle emptyStateSubtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppConstants.textSecondary,
  );
}
