import 'package:flutter/material.dart';

/// Creates a page route with no animation (instant transition)
/// Use this instead of MaterialPageRoute for instant transitions
class NoAnimationPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  NoAnimationPageRoute({required this.builder, RouteSettings? settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}

/// Helper function to create a route with no animation
/// This is a drop-in replacement for MaterialPageRoute
PageRoute<T> createNoAnimationRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return NoAnimationPageRoute<T>(
    builder: builder,
    settings: settings,
  );
}

