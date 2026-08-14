import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in session, in one place.
///
/// Tokens used to be written and read as loose `prefs.getString('access_token')`
/// calls scattered across screens and services. That was survivable while a
/// token lasted thirty days and never changed after login. It stopped being
/// survivable when the access token became fifteen minutes long: something now
/// rewrites it every quarter of an hour, and every reader has to see that new
/// value immediately.
///
/// Two tokens are stored:
///
///  * the **access token** — short-lived, sent as `Authorization: Bearer` on
///    every request, and expected to expire routinely;
///  * the **refresh token** — thirty days, sent to `/auth/refresh` and nowhere
///    else, and the only thing standing between an expired access token and
///    being thrown back to the login screen.
class WaslSession {
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  /// Everything that identifies the signed-in user, cleared together on logout.
  static const List<String> _sessionKeys = [
    accessTokenKey,
    refreshTokenKey,
    'user_id',
    'user_name',
    'user_phone',
    'user_role',
  ];

  const WaslSession();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> accessToken() async =>
      _nonEmpty((await _prefs).getString(accessTokenKey));

  Future<String?> refreshToken() async =>
      _nonEmpty((await _prefs).getString(refreshTokenKey));

  /// Stores what a sign-in or a refresh returned.
  ///
  /// The refresh token is optional because rotation may legitimately hand back
  /// only an access token; passing null leaves the stored one alone rather than
  /// erasing the credential that renews the session.
  Future<void> save({required String accessToken, String? refreshToken}) async {
    final prefs = await _prefs;
    await prefs.setString(accessTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(refreshTokenKey, refreshToken);
    }
  }

  /// Drops the session and nothing else.
  ///
  /// Deliberately not `prefs.clear()`: this runs unattended when a refresh
  /// fails, and wiping the whole store would take unrelated preferences —
  /// language, saved area, onboarding flags — with it. What must go is anything
  /// that would let the app keep acting signed in.
  Future<void> clear() async {
    final prefs = await _prefs;
    for (final key in _sessionKeys) {
      await prefs.remove(key);
    }
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}
