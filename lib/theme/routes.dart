import 'package:flutter/material.dart';

class _FadeLiftRoute<T> extends PageRouteBuilder<T> {
  _FadeLiftRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

class _FadeRoute<T> extends PageRouteBuilder<T> {
  _FadeRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
        );
}

abstract class AppRoutes {
  static Future<T?> push<T>(
    BuildContext context,
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) =>
      Navigator.of(context)
          .push(_FadeLiftRoute<T>(builder: builder, settings: settings));

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) =>
      Navigator.of(context).pushReplacement(
          _FadeRoute<T>(builder: builder, settings: settings));
}
