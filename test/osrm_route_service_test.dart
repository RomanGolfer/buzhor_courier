import 'package:buzhor_courier/features/route/services/osrm_route_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const from = LatLng(44.8951, 37.3168);
  const to = LatLng(44.9021, 37.3378);

  test('fetchSegment uses HTTPS OSRM geometry', () async {
    Uri? requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"routes":[{"geometry":{"coordinates":[[37.3168,44.8951],[37.32,44.9],[37.3378,44.9021]]}}]}',
        200,
      );
    });

    final segment = await OsrmRouteService.fetchSegment(
      from,
      to,
      client: client,
    );

    expect(requestedUri?.scheme, 'https');
    expect(requestedUri?.host, 'router.project-osrm.org');
    expect(segment, hasLength(3));
    expect(segment[1].latitude, 44.9);
    expect(segment[1].longitude, 37.32);
  });

  test('fetchSegment falls back to straight line on errors', () async {
    final client = MockClient((request) async => http.Response('nope', 500));

    final segment = await OsrmRouteService.fetchSegment(
      from,
      to,
      client: client,
    );

    expect(segment, [from, to]);
  });
}
