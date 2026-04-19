import 'package:ams_app/features/settings/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _serverUrlKey = 'server_ip';
  static const String _roomIdKey = 'room_id';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      serverUrl: prefs.getString(_serverUrlKey)?.trim() ?? '',
      roomId: prefs.getString(_roomIdKey)?.trim() ?? '',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, normalizeUrl(settings.serverUrl));
    await prefs.setString(_roomIdKey, settings.roomId.trim());
  }

  String normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    return 'http://$trimmed';
  }
}
