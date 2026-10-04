import 'dart:ui' show DisplayFeature, DisplayFeatureType;
import 'package:flutter/widgets.dart';

/// Data class detailing the geometry of a foldable or dual-screen device.
class FoldablePaneInfo {
  final bool isTwoPane;
  final bool hasPhysicalHinge;
  final Rect? hingeBounds;
  final double leftPaneWidth;
  final double rightPaneWidth;
  final double hingeGap;

  const FoldablePaneInfo({
    required this.isTwoPane,
    required this.hasPhysicalHinge,
    this.hingeBounds,
    required this.leftPaneWidth,
    required this.rightPaneWidth,
    required this.hingeGap,
  });
}

/// Helper utilities for detecting foldable and dual-screen device postures,
/// specifically tuned for iPhone Duo and foldable iOS/Android devices.
class FoldableUtils {
  FoldableUtils._();

  /// Checks if any physical hinge or fold display feature is active.
  static bool isFoldable(BuildContext context) {
    final features = MediaQuery.of(context).displayFeatures;
    return features.any(
      (f) => f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold,
    );
  }

  /// Returns the vertical hinge or fold feature that splits the display
  /// into left and right sub-screens, if present.
  static DisplayFeature? getVerticalHinge(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final features = mediaQuery.displayFeatures;

    for (final feature in features) {
      if (feature.type == DisplayFeatureType.hinge || feature.type == DisplayFeatureType.fold) {
        // Vertical hinge: height significantly exceeds width, and it spans a substantial portion of the screen
        if (feature.bounds.height > feature.bounds.width &&
            feature.bounds.height >= mediaQuery.size.height * 0.4) {
          return feature;
        }
      }
    }
    return null;
  }

  /// Returns the horizontal hinge or fold feature (e.g. laptop or tabletop posture),
  /// if present.
  static DisplayFeature? getHorizontalHinge(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final features = mediaQuery.displayFeatures;

    for (final feature in features) {
      if (feature.type == DisplayFeatureType.hinge || feature.type == DisplayFeatureType.fold) {
        if (feature.bounds.width > feature.bounds.height &&
            feature.bounds.width >= mediaQuery.size.width * 0.4) {
          return feature;
        }
      }
    }
    return null;
  }

  /// True if the device is currently eligible for a two-pane layout:
  /// either because it has a vertical hinge/fold (iPhone Duo unfolded)
  /// or because the available screen width is >= 600pt (iPhone Duo 669pt / iPad / Mac / Desktop / Web).
  static bool isTwoPaneEligible(BuildContext context) {
    if (getVerticalHinge(context) != null) {
      return true;
    }
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Calculates pane dimensions avoiding the hinge crease.
  static FoldablePaneInfo getPaneInfo(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final totalWidth = mediaQuery.size.width;
    final hinge = getVerticalHinge(context);

    if (hinge != null) {
      final hingeRect = hinge.bounds;
      final leftWidth = hingeRect.left > 0 ? hingeRect.left : (totalWidth - hingeRect.width) / 2;
      final rightWidth = (totalWidth - hingeRect.right) > 0 ? (totalWidth - hingeRect.right) : leftWidth;
      final gap = hingeRect.width > 0 ? hingeRect.width : 16.0;

      return FoldablePaneInfo(
        isTwoPane: true,
        hasPhysicalHinge: true,
        hingeBounds: hingeRect,
        leftPaneWidth: leftWidth,
        rightPaneWidth: rightWidth,
        hingeGap: gap,
      );
    }

    // Wide screen or unfolded foldable without physical hinge (e.g. iPhone Duo 669pt, iPad, Mac, Web)
    if (totalWidth >= 600) {
      // Allocate proportionate panes with a clean 16px divider
      const gap = 16.0;
      final available = totalWidth - gap;
      final leftRatio = totalWidth < 768 ? 0.48 : 0.42;
      final leftWidth = (available * leftRatio).clamp(260.0, 480.0);
      final rightWidth = available - leftWidth;

      return FoldablePaneInfo(
        isTwoPane: true,
        hasPhysicalHinge: false,
        leftPaneWidth: leftWidth,
        rightPaneWidth: rightWidth,
        hingeGap: gap,
      );
    }

    // Single screen (Folded phone or standard portrait mobile)
    return FoldablePaneInfo(
      isTwoPane: false,
      hasPhysicalHinge: false,
      leftPaneWidth: totalWidth,
      rightPaneWidth: 0,
      hingeGap: 0,
    );
  }
}
