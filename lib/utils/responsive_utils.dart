import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Screen size breakpoints
  static const double mobileBreakpoint = 480.0;
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;

  // Check device type based on width
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  // Get adaptive value based on screen size
  static double getAdaptiveSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return desktop ?? tablet ?? mobile;
    }

    if (width >= tabletBreakpoint) {
      return tablet ?? mobile;
    }

    return mobile;
  }

  // Get adaptive padding
  static EdgeInsets getAdaptivePadding(
    BuildContext context, {
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return desktop ?? tablet ?? mobile;
    }

    if (width >= tabletBreakpoint) {
      return tablet ?? mobile;
    }

    return mobile;
  }

  // Get adaptive text style
  static TextStyle getAdaptiveTextStyle(
    BuildContext context, {
    required TextStyle mobile,
    TextStyle? tablet,
    TextStyle? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return desktop ?? tablet ?? mobile;
    }

    if (width >= tabletBreakpoint) {
      return tablet ?? mobile;
    }

    return mobile;
  }

  // Get adaptive width
  static double getAdaptiveWidth(
    BuildContext context, {
    required double percentageOfScreen,
    double maxWidth = double.infinity,
  }) {
    final width = MediaQuery.of(context).size.width * percentageOfScreen;
    return width > maxWidth ? maxWidth : width;
  }

  // Get adaptive height for certain widgets
  static double getAdaptiveHeight(
    BuildContext context, {
    required double percentageOfScreen,
    double maxHeight = double.infinity,
  }) {
    final height = MediaQuery.of(context).size.height * percentageOfScreen;
    return height > maxHeight ? maxHeight : height;
  }

  // Get adaptive grid crossAxisCount
  static int getAdaptiveGridCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return 4; // Desktop shows 4 items per row
    }

    if (width >= tabletBreakpoint) {
      return 3; // Tablet shows 3 items per row
    }

    // Mobile shows 2 items per row
    return 2;
  }

  // Get adaptive column count for list views
  static int getAdaptiveColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return 2; // Desktop can show side-by-side columns
    }

    // Tablet and mobile use single column
    return 1;
  }
}
