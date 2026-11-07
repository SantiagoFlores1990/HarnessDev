import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/layout/breakpoints.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Aplicacion Good Pizza: Material 3 claro, espanol, go_router.
class GoodPizzaApp extends ConsumerWidget {
  const GoodPizzaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => MinWindowSize(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Tamano minimo de ventana 1024x680 solo recomendado: por debajo no se recorta, se desplaza
/// (sin anadir `window_manager`).
class MinWindowSize extends StatelessWidget {
  const MinWindowSize({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final needsScroll = size.width < Breakpoints.minRecommendedWidth || size.height < Breakpoints.minRecommendedHeight;
    if (!needsScroll) return child;
    final w = math.max(size.width, Breakpoints.minRecommendedWidth);
    final h = math.max(size.height, Breakpoints.minRecommendedHeight);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SizedBox(
          width: w,
          height: h,
          child: MediaQuery(data: media.copyWith(size: Size(w, h)), child: child),
        ),
      ),
    );
  }
}
