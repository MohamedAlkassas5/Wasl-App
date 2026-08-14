import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wasl_app/core/network/authed_http.dart';
import 'package:wasl_app/core/session/wasl_session.dart';

/// The access token is fifteen minutes long, which means every signed-in user
/// meets a 401 several times an hour during perfectly normal use — mid-order,
/// mid-delivery. These pin the recovery: refresh once, retry once, and never
/// turn a routine expiry into a logout or a loop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = WaslSession();
  const base = 'http://test.local';
  final endpoint = Uri.parse('$base/orders');

  /// Requests the client made, in order, as `METHOD /path` plus the token sent.
  late List<String> calls;
  late List<String?> bearers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'old-access',
      'refresh_token': 'the-refresh-token',
      'user_id': 42,
    });
    calls = [];
    bearers = [];
    WaslAuthedHttp.onSignedOut = null;
  });

  /// A server that 401s any request presenting a stale access token, and hands
  /// out `new-access` in exchange for a valid refresh token.
  MockClient serverWith({
    required bool refreshSucceeds,
    String newAccess = 'new-access',
    Duration refreshDelay = Duration.zero,
  }) {
    return MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final auth = request.headers['Authorization'];
      bearers.add(auth);

      if (request.url.path == '/auth/refresh') {
        if (refreshDelay > Duration.zero) await Future.delayed(refreshDelay);
        if (!refreshSucceeds) {
          return http.Response(jsonEncode({'message': 'expired'}), 401);
        }
        return http.Response(
          jsonEncode({
            'token': newAccess,
            'refreshToken': 'rotated-refresh-token',
          }),
          200,
        );
      }

      final presented = auth?.replaceFirst('Bearer ', '');
      if (presented != newAccess) {
        return http.Response(jsonEncode({'message': 'expired'}), 401);
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });
  }

  WaslAuthedHttp clientFor(MockClient mock) =>
      WaslAuthedHttp(client: mock, session: session, baseUrl: base);

  test('sends the stored access token', () async {
    final mock = MockClient((request) async {
      bearers.add(request.headers['Authorization']);
      return http.Response('{}', 200);
    });

    await clientFor(mock).get(endpoint);

    expect(bearers.single, 'Bearer old-access');
  });

  test('refreshes on 401 and retries the request once', () async {
    final response = await clientFor(serverWith(refreshSucceeds: true))
        .get(endpoint);

    expect(response.statusCode, 200);
    expect(calls, [
      'GET /orders', // 401, the token had expired
      'POST /auth/refresh',
      'GET /orders', // retried, now with the new token
    ]);
    expect(bearers.last, 'Bearer new-access');
  });

  test('persists both tokens after a refresh', () async {
    await clientFor(serverWith(refreshSucceeds: true)).get(endpoint);

    expect(await session.accessToken(), 'new-access');
    // The refresh token rotates on every use; keeping the old one would make
    // the next refresh look like replay and end the session.
    expect(await session.refreshToken(), 'rotated-refresh-token');
  });

  test('leaves unrelated preferences alone on a successful refresh', () async {
    await clientFor(serverWith(refreshSucceeds: true)).get(endpoint);
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getInt('user_id'), 42);
  });

  test('retries only once — a second 401 is the answer', () async {
    // Refresh succeeds but hands back a token the resource still rejects.
    final mock = serverWith(refreshSucceeds: true, newAccess: 'still-wrong');
    final client = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({'token': 'no-good', 'refreshToken': 'r2'}),
            200,
          );
        }
        return http.Response(jsonEncode({'message': 'expired'}), 401);
      }),
      session: session,
      baseUrl: base,
    );
    mock.close();

    final response = await client.get(endpoint);

    expect(response.statusCode, 401);
    expect(calls, ['GET /orders', 'POST /auth/refresh', 'GET /orders']);
  });

  test('concurrent 401s share a single refresh', () async {
    final client = clientFor(
      serverWith(
        refreshSucceeds: true,
        // Long enough that all four requests are waiting on the same refresh.
        refreshDelay: const Duration(milliseconds: 50),
      ),
    );

    final responses = await Future.wait([
      client.get(endpoint),
      client.get(endpoint),
      client.get(endpoint),
      client.get(endpoint),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    // The whole point: four expired requests, one refresh. Four refreshes would
    // mean three of them presenting an already-rotated token, which the server
    // reads as theft and answers by revoking the entire family.
    expect(calls.where((c) => c.contains('/auth/refresh')).length, 1);
  });

  test('a request that 401s after someone else refreshed just retries',
      () async {
    final client = clientFor(serverWith(refreshSucceeds: true));

    // First request refreshes and stores `new-access`.
    await client.get(endpoint);
    calls.clear();

    // Now a request that was in flight with the old token comes back 401. It
    // must not refresh again — the stored token is already newer than the one
    // it sent, and spending the rotated refresh token would end the session.
    final late = WaslAuthedHttp(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final presented =
            request.headers['Authorization']?.replaceFirst('Bearer ', '');
        if (request.url.path == '/auth/refresh') {
          return http.Response(jsonEncode({'message': 'reuse'}), 401);
        }
        return presented == 'new-access'
            ? http.Response('{}', 200)
            : http.Response('{}', 401);
      }),
      session: session,
      baseUrl: base,
    );

    final response = await late.get(endpoint);

    expect(response.statusCode, 200);
    expect(calls, ['GET /orders']);
  });

  group('when the refresh fails', () {
    test('clears the session', () async {
      await clientFor(serverWith(refreshSucceeds: false)).get(endpoint);

      expect(await session.accessToken(), isNull);
      expect(await session.refreshToken(), isNull);
    });

    test('announces the sign-out so the app can leave the screen', () async {
      var signedOut = 0;
      WaslAuthedHttp.onSignedOut = () => signedOut++;

      await clientFor(serverWith(refreshSucceeds: false)).get(endpoint);

      expect(signedOut, 1);
    });

    test('returns the original 401 rather than throwing', () async {
      final response =
          await clientFor(serverWith(refreshSucceeds: false)).get(endpoint);

      expect(response.statusCode, 401);
    });

    test('does not try to refresh when there is no refresh token', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'old-access'});

      final response =
          await clientFor(serverWith(refreshSucceeds: true)).get(endpoint);

      expect(response.statusCode, 401);
      expect(calls, ['GET /orders']);
    });

    test('survives the refresh call throwing', () async {
      final client = WaslAuthedHttp(
        client: MockClient((request) async {
          calls.add(request.url.path);
          if (request.url.path == '/auth/refresh') {
            throw const SocketishFailure();
          }
          return http.Response('{}', 401);
        }),
        session: session,
        baseUrl: base,
      );

      // A refresh that fails on the network must not surface as an unhandled
      // exception in the middle of whatever screen made the request.
      final response = await client.get(endpoint);
      expect(response.statusCode, 401);
    });
  });

  test('does not refresh when the response was not a 401', () async {
    final mock = MockClient((request) async {
      calls.add(request.url.path);
      return http.Response(jsonEncode({'message': 'forbidden'}), 403);
    });

    final response = await clientFor(mock).get(endpoint);

    // 403 is "you may not", not "prove yourself again". Refreshing would spend
    // a refresh token to no purpose.
    expect(response.statusCode, 403);
    expect(calls, ['/orders']);
  });
}

/// Stands in for a network-level failure without depending on dart:io.
class SocketishFailure implements Exception {
  const SocketishFailure();
}
