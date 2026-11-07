import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(
    // Sin reintentos automaticos de providers: los errores se muestran con "Reintentar".
    ProviderScope(
      retry: (_, _) => null,
      child: const GoodPizzaApp(),
    ),
  );
}
