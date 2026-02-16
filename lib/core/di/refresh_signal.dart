import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple counter that gets incremented whenever data or settings
/// change.  Providers that `ref.watch` this will automatically rebuild.
class RefreshSignal extends StateNotifier<int> {
  RefreshSignal() : super(0);

  void notify() => state++;
}

final refreshSignalProvider =
    StateNotifierProvider<RefreshSignal, int>((ref) => RefreshSignal());
