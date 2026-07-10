import 'package:shared_preferences/shared_preferences.dart';
class SyncPrefs
{
  static Future<void> setUnsyncedStatus(bool value)async
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_unsynced_polls', value);
  }
  static Future<bool> hasUnsyncedPolls()
  async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_unsynced_polls') ?? false;
  }
}