import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/foldable_utils.dart';

/// A hinge-aware, adaptive two-pane layout container designed for
/// iPhone Duo and foldable / dual-screen devices.
///
/// On single-screen (folded) devices, it displays [singlePane] (or [startPane]).
/// On unfolded or dual-screen devices, it neatly positions [startPane] on the
/// left and [endPane] on the right, ensuring the physical hinge/crease area
/// is completely respected and never overlapped by interactive UI.
class FoldableTwoPane extends StatelessWidget {
  /// The widget rendered in the start/left pane (e.g. Master list, Overview, Controls).
  final Widget startPane;

  /// The widget rendered in the end/right pane (e.g. Details, Action canvas, Recent list).
  final Widget endPane;

  /// Optional widget displayed when in single-screen (folded) mode.
  /// If null, [startPane] is used.
  final Widget? singlePane;

  /// Optional fixed width for the start pane. If null, automatically computed
  /// based on device geometry and hinge bounds.
  final double? startPaneWidth;

  /// Custom divider between panes. If null, a subtle divider with hinge cushion is rendered.
  final Widget? divider;

  const FoldableTwoPane({
    super.key,
    required this.startPane,
    required this.endPane,
    this.singlePane,
    this.startPaneWidth,
    this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final paneInfo = FoldableUtils.getPaneInfo(context);

    if (!paneInfo.isTwoPane) {
      return singlePane ?? startPane;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate effective left pane width
        final double effectiveLeftWidth;
        if (startPaneWidth != null) {
          effectiveLeftWidth = startPaneWidth!;
        } else if (paneInfo.hasPhysicalHinge) {
          effectiveLeftWidth = paneInfo.leftPaneWidth.clamp(260.0, constraints.maxWidth - 260.0);
        } else {
          // Proportionate split for non-hinge wide screens & unfolded foldables
          final leftRatio = constraints.maxWidth < 768 ? 0.48 : 0.42;
          effectiveLeftWidth = (constraints.maxWidth * leftRatio).clamp(260.0, 480.0);
        }

        final double gap = paneInfo.hasPhysicalHinge ? paneInfo.hingeGap.clamp(4.0, 48.0) : 16.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane (Start)
            SizedBox(
              width: effectiveLeftWidth,
              child: ClipRect(child: startPane),
            ),

            // Hinge cushion / Divider
            divider ??
                Container(
                  width: gap,
                  color: paneInfo.hasPhysicalHinge
                      ? Colors.transparent
                      : AppColors.softBackground,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: AppColors.border.withAlpha(120),
                    ),
                  ),
                ),

            // Right Pane (End)
            Expanded(
              child: ClipRect(child: endPane),
            ),
          ],
        );
      },
    );
  }
}
