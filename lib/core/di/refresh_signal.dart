import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple counter that gets incremented whenever data or settings
/// change. Providers that `ref.watch` this will automatically rebuild.
class RefreshSignal extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final refreshSignalProvider =
    NotifierProvider<RefreshSignal, int>(RefreshSignal.new);
