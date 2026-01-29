import 'package:flutter/material.dart';
import 'telegraph_key.dart';

/// A standardized layout for the TelegraphKey with optional button columns on either side.
/// This ensures consistent visual appearance across all screens.
class TelegraphKeyLayout extends StatelessWidget {
  /// Callback when the key is pressed down
  final VoidCallback? onKeyDown;

  /// Callback when the key is released
  final VoidCallback? onKeyUp;

  /// Callback with press duration (alternative to onKeyDown/onKeyUp)
  final void Function(int duration)? onPress;

  /// Whether the key is enabled
  final bool enabled;

  /// Scale factor for the telegraph key (default 0.8)
  final double scale;

  /// Widgets to display in the left column (up to 3)
  /// If null or empty, invisible spacers are used for balance
  final List<Widget>? leftColumnButtons;

  /// Widgets to display in the right column (up to 3)
  /// If null or empty, invisible spacers are used for balance
  final List<Widget>? rightColumnButtons;

  /// Bottom padding for the entire layout
  final double bottomPadding;

  const TelegraphKeyLayout({
    super.key,
    this.onKeyDown,
    this.onKeyUp,
    this.onPress,
    this.enabled = true,
    this.scale = 0.8,
    this.leftColumnButtons,
    this.rightColumnButtons,
    this.bottomPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left column
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildColumn(leftColumnButtons),
          ),
          // Telegraph key in center
          TelegraphKey(
            onKeyDown: onKeyDown,
            onKeyUp: onKeyUp,
            onPress: onPress,
            enabled: enabled,
            scale: scale,
          ),
          // Right column
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildColumn(rightColumnButtons),
          ),
        ],
      ),
    );
  }

  /// Build a column with the provided buttons, or invisible spacers if none
  Widget _buildColumn(List<Widget>? buttons) {
    // Standard button size
    const double buttonSize = 56;
    const double gapSize = 12;

    if (buttons == null || buttons.isEmpty) {
      // Return invisible spacers matching the standard 3-button layout
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: buttonSize, height: buttonSize),
          SizedBox(height: gapSize),
          SizedBox(width: buttonSize, height: buttonSize),
          SizedBox(height: gapSize),
          SizedBox(width: buttonSize, height: buttonSize),
        ],
      );
    }

    // Build column with provided buttons and gaps
    final List<Widget> children = [];
    for (int i = 0; i < 3; i++) {
      if (i < buttons.length) {
        children.add(buttons[i]);
      } else {
        // Fill remaining slots with invisible spacers
        children.add(const SizedBox(width: buttonSize, height: buttonSize));
      }
      if (i < 2) {
        children.add(const SizedBox(height: gapSize));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
