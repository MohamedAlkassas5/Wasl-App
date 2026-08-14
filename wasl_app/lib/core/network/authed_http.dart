import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../session/wasl_session.dart';

/// The authenticated way out of the app.
///
/// Every request that needs a signed-in user goes through here, because the
/// access token is now fifteen minutes long and something has to notice when it
/// runs out. Before this existed, each call site built its own headers and
/// treated a 401 as a generic failure — which was harmless while tokens lasted
/// thirty days, and would have meant "signed out mid-order" once they lasted
/// fifteen minutes.
///
/// What it does on a 401:
///
///  1. checks whether another request already refreshed while this one was in
///     flight — if so it just retries, because refreshing again would present
///     an already-rotated token and the server would read that as theft;
///  2. otherwise refreshes, at most one refresh at a time no matter how many
///     requests are waiting;
///  3. retries the original request **once**, and returns whatever that gives —
///     a second 401 is an answer, not an invitation to try again;
///  4. if the refresh itself fails, clears the session so the app stops
///     pretending to be signed in.
class WaslAuthedHttp {
  WaslAuthedHttp({
    http.Client? client,
    WaslSession session = const WaslSession(),
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _session = session,
        _baseUrl = baseUrl;

  /// The instance the app uses. Replaceable so tests can drive a fake client.
  static WaslAuthedHttp instance = WaslAuthedHttp();

  final http.Client _client;
  final WaslSession _session;
  final String? _baseUrl;

  /// Called when the session is gone for good and the user must sign in again.
  ///
  /// A callback rather than navigation: this layer knows nothing about widgets,
  /// and a refresh can fail on a background poll where there is no context to
  /// push a route from.
  static void Function()? onSignedOut;

  /// The in-progress refresh, shared by everyone waiting on one.
  ///
  /// This is the single-flight guard, and it is not an optimisation. Refresh
  /// tokens rotate: two refreshes racing means the second presents a token the
  /// first already spent, the server treats that as replay, and it revokes the
  /// entire family — signing the user out of the very session this was meant to
  /// preserve. Firing one refresh per concurrent 401 would make a screen that
  /// loads four things at once a reliable way to get logged out.
  Future<bool>? _refreshInFlight;

  String get _base => _baseUrl ?? WaslApiConfig.baseUrl;

  /// `headers` is merged over the defaults — for the odd request that is not
  /// JSON, such as fetching an image behind auth.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) =>
      _run((h) => _client.get(url, headers: h), timeout, extra: headers);

  Future<http.Response> post(Uri url, {Object? body, Duration? timeout}) =>
      _run((headers) => _client.post(url, headers: headers, body: body),
          timeout);

  Future<http.Response> put(Uri url, {Object? body, Duration? timeout}) =>
      _run(
          (headers) => _client.put(url, headers: headers, body: body), timeout);

  Future<http.Response> patch(Uri url, {Object? body, Duration? timeout}) =>
      _run((headers) => _client.patch(url, headers: headers, body: body),
          timeout);

  Future<http.Response> delete(Uri url, {Object? body, Duration? timeout}) =>
      _run((headers) => _client.delete(url, headers: headers, body: body),
          timeout);

  /// For multipart uploads, which cannot be replayed.
  ///
  /// A `MultipartRequest` streams its files and is spent once sent, so a retry
  /// needs a brand-new one — hence a builder rather than a request. The builder
  /// is called again, from scratch, if the first attempt comes back 401.
  Future<http.Response> sendMultipart(
    Future<http.MultipartRequest> Function() build, {
    Duration? timeout,
  }) =>
      _run((headers) async {
        final request = await build()
          ..headers.addAll(headers);
        // multipart sets its own Content-Type, boundary and all.
        request.headers.remove('Content-Type');
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      }, timeout);

  /// Attach credentials, send, and deal with a 401 exactly once.
  Future<http.Response> _run(
    Future<http.Response> Function(Map<String, String> headers) attempt,
    Duration? timeout, {
    Map<String, String>? extra,
  }) async {
    final tokenUsed = await _session.accessToken();

    var response = await _attempt(attempt, tokenUsed, timeout, extra);
    if (response.statusCode != 401) return response;

    if (!await _recoverFrom401(tokenUsed)) {
      await _signOut();
      return response;
    }

    // Exactly one retry. Whatever this returns is the answer — looping on a
    // second 401 would hammer the server and, worse, keep rotating refresh
    // tokens until the family tripped the reuse check.
    final refreshed = await _session.accessToken();
    return _attempt(attempt, refreshed, timeout, extra);
  }

  Future<http.Response> _attempt(
    Future<http.Response> Function(Map<String, String> headers) attempt,
    String? token,
    Duration? timeout,
    Map<String, String>? extra,
  ) {
    final headers = Map<String, String>.from(WaslApiConfig.jsonHeaders);
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (extra != null) headers.addAll(extra);

    final sent = attempt(headers);
    return timeout == null ? sent : sent.timeout(timeout);
  }

  /// True when there is a usable access token to retry with.
  Future<bool> _recoverFrom401(String? tokenUsed) async {
    // Someone else refreshed while this request was in flight. Its 401 is stale
    // news; the stored token is already newer than the one it sent, so retry on
    // that rather than spending a refresh token nobody needed to spend.
    final current = await _session.accessToken();
    if (current != null && current != tokenUsed) return true;

    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _refresh() async {
    final refreshToken = await _session.refreshToken();
    if (refreshToken == null) return false;

    try {
      // Deliberately the bare client: this must never route back through _run,
      // or a failing refresh would try to refresh itself.
      final response = await _client
          .post(
            Uri.parse('$_base/auth/refresh'),
            headers: WaslApiConfig.jsonHeaders,
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }

      final body = jsonDecode(response.body);
      if (body is! Map) return false;

      final access = body['token']?.toString() ?? '';
      if (access.isEmpty) return false;

      await _session.save(
        accessToken: access,
        refreshToken: body['refreshToken']?.toString(),
      );
      return true;
    } catch (_) {
      // A refresh that failed on the network is not proof the session is over,
      // but there is nothing to retry the original request with either. The
      // caller gets its 401 and the user signs in again — annoying, and far
      // better than a spinner that never resolves.
      return false;
    }
  }

  Future<void> _signOut() async {
    await _session.clear();
    onSignedOut?.call();
  }
}
