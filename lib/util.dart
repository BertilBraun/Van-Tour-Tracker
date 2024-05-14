import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

const bool IS_WEB_BUILD = true;
const String GEOAPIFY_API_KEY = "225dc37a5e42447c838ec18e43b40b5d";
const String OPEN_ROUTE_SERVICE_API_KEY =
    '5b3ce3597851110001cf6248f95e0f2fb83c4c0289b9516af2f95e38';

String pointToString(LatLng point) => '${point.latitude},${point.longitude}';

LatLng parsePoint(String text) {
  final List<String> latLng = text.split(',');
  return LatLng(double.parse(latLng[0]), double.parse(latLng[1]));
}

List<LatLng> parsePoints(String text) =>
    text.split(';').map(parsePoint).toList();

Future<List<LatLng>> fetchRoute(LatLng origin, LatLng destination) async {
  final response = await http.get(Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car?api_key=${OPEN_ROUTE_SERVICE_API_KEY}&start=${origin.longitude},${origin.latitude}&end=${destination.longitude},${destination.latitude}'));

  List<LatLng> points = [origin, destination];

  if (response.statusCode == 200) {
    final Map data = jsonDecode(response.body);
    final List<LatLng> routeCoordinates =
        (data['features'][0]['geometry']['coordinates'] as List)
            .map((coord) => LatLng(coord[1], coord[0]))
            .toList();

    points.insertAll(1, routeCoordinates);
  }
  return points;
}

Future<LatLng?> getLocation({bool showPrompt = false}) async {
  final Location location = Location();

  PermissionStatus permission = await location.hasPermission();
  if (permission == PermissionStatus.denied) {
    permission = await location.requestPermission();
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      if (showPrompt) {
        // TODO show a popup or sth like that to ask the user to allow the location access to the app
      }
      return null;
    }
  }

  final LocationData currentLocation = await location.getLocation();

  if (currentLocation.latitude == null || currentLocation.longitude == null) {
    return null;
  }

  return LatLng(currentLocation.latitude!, currentLocation.longitude!);
}
