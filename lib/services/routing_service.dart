import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:helloworld/settings.dart';
import 'package:helloworld/data/route_data.dart';

class RoutingService {
  static Future<Route> fetchRoute(LatLng origin, LatLng destination) async {
    final response = await http.get(Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$OPEN_ROUTE_SERVICE_API_KEY&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}'));

    List<LatLng> points = [origin, destination];
    double distance = 0; // TODO calculate air distance

    if (response.statusCode == 200) {
      final Map data = jsonDecode(response.body);
      final List<LatLng> routeCoordinates =
          (data['features'][0]['geometry']['coordinates'] as List)
              .map((coord) => LatLng(coord[1], coord[0]))
              .toList();

      points.insertAll(1, routeCoordinates);

      distance = data['features'][0]['properties']['summary']['distance'];
    }

    return Route(origin, destination, points, distance);
  }
}
