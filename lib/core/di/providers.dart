import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chronosense/data/repository/journal_repository_impl.dart';
import 'package:chronosense/data/repository/preferences_repository_impl.dart';

/// Singleton repository providers — manual DI, mirrors AppModule.kt
final journalRepositoryProvider = Provider<JournalRepositoryImpl>((ref) {
  return JournalRepositoryImpl();
});

final preferencesRepositoryProvider = Provider<PreferencesRepositoryImpl>((ref) {
  return PreferencesRepositoryImpl();
});
