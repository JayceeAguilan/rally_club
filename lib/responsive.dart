import 'package:flutter/material.dart';

/// Responsive layout helper for Rally Club.
/// Provides adaptive sizes based on screen width.
class Responsive {
  final BuildContext context;

  Responsive(this.context);

  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;

  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;

  /// Horizontal page padding — compact on mobile, wider on tablet/desktop.
  double get pagePadding {
    if (isMobile) return 16.0;
    if (isTablet) return 32.0;
    return 48.0;
  }

  /// Vertical section spacing.
  double get sectionSpacing {
    if (isMobile) return 20.0;
    return 32.0;
  }

  /// Card border radius — slightly smaller on mobile.
  double get cardRadius {
    if (isMobile) return 20.0;
    return 24.0;
  }

  /// Card internal padding.
  double get cardPadding {
    if (isMobile) return 16.0;
    return 24.0;
  }

  /// Title font size.
  double get titleSize {
    if (isMobile) return 28.0;
    if (isTablet) return 32.0;
    return 36.0;
  }

  /// Subtitle font size.
  double get subtitleSize {
    if (isMobile) return 18.0;
    return 20.0;
  }

  /// Body font size.
  double get bodySize {
    if (isMobile) return 13.0;
    return 14.0;
  }

  /// Small label size.
  double get labelSize {
    if (isMobile) return 9.0;
    return 10.0;
  }

  /// Max content width (for centering on very wide screens).
  double get maxContentWidth {
    if (isDesktop) return 900.0;
    return double.infinity;
  }

  /// Number of grid columns for card grids.
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }

  /// Bottom padding to clear the bottom nav bar on mobile.
  double get bottomNavPadding {
    if (isMobile) return 100.0;
    return 32.0;
  }

  /// Wraps content in a centered container with max width on desktop.
  Widget constrainWidth({required Widget child}) {
    if (maxContentWidth == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
