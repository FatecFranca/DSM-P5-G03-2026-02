import 'package:shared_preferences/shared_preferences.dart';

/// Preferência local de apresentação; independente de GPS e autenticação.
class IntroPreferences {
  IntroPreferences._(this._preferences);

  static const completedKey = 'firewatch.intro_completed.v1';
  final SharedPreferences _preferences;

  static Future<IntroPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return IntroPreferences._(preferences);
  }

  bool get completed => _preferences.getBool(completedKey) == true;

  Future<void> complete() async {
    if (!await _preferences.setBool(completedKey, true)) {
      throw StateError(
        'Não foi possível salvar a preferência de apresentação.',
      );
    }
  }
}
