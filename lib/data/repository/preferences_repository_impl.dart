import 'package:chronosense/data/preferences/user_preferences_store.dart';
import 'package:chronosense/domain/model/models.dart';

/// Repository for user preferences.
class PreferencesRepositoryImpl {
  final UserPreferencesStore _store;

  PreferencesRepositoryImpl({UserPreferencesStore? store})
      : _store = store ?? UserPreferencesStore.instance;

  Future<UserPreferences> getPreferences() => _store.load();

  Future<void> updatePreferences(
    UserPreferences Function(UserPreferences current) transform,
  ) async {
    final current = await _store.load();
    final updated = transform(current);
    await _store.save(updated);
  }
}
