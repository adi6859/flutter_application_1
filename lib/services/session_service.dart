import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const String _loggedInKey = 'session_logged_in';
  static const String _emailKey = 'session_email';

  static Future<void> saveLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_emailKey, email);
  }

  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    await prefs.remove(_emailKey);
  }

  static Future<({bool loggedIn, String email})> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_loggedInKey) ?? false;
    final email = prefs.getString(_emailKey) ?? '';
    return (loggedIn: loggedIn, email: email);
  }
}
