import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 1200) {
        return desktop;
      } else if (constraints.maxWidth >= 600) {
        return tablet;
      } else {
        return mobile;
      }
    });
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      ScreenType type;
      if (constraints.maxWidth >= 1200) {
        type = ScreenType.desktop;
      } else if (constraints.maxWidth >= 600) {
        type = ScreenType.tablet;
      } else {
        type = ScreenType.mobile;
      }
      return builder(context, type);
    });
  }
}

enum ScreenType { mobile, tablet, desktop }

extension ScreenTypeExtension on ScreenType {
  bool get isMobile => this == ScreenType.mobile;
  bool get isTablet => this == ScreenType.tablet;
  bool get isDesktop => this == ScreenType.desktop;
}
