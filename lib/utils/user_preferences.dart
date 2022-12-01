import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static SharedPreferences? _preferences;
  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setLastSyncDate(String date) async =>
      await _preferences!.setString('lastSyncDate', date);

  static String? getLastSyncDate() => _preferences!.getString('lastSyncDate');
}
