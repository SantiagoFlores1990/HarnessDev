import 'dart:async';

import 'package:flutter/foundation.dart';

/// Retrasa una accion hasta que pasa [delay] sin nuevas llamadas.
class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();
}
