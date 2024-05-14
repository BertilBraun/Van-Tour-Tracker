import 'package:helloworld/marker_data.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';

String pointToString(LatLng point) => '${point.latitude},${point.longitude}';

String pointsToString(Iterable<LatLng> points) =>
    points.map(pointToString).join(';');

LatLng parsePoint(String text) {
  final List<String> latLng = text.split(',');
  return LatLng(double.parse(latLng[0]), double.parse(latLng[1]));
}

List<LatLng> parsePoints(String text) =>
    text.split(';').map(parsePoint).toList();

Future<Map<LatLng, MarkerData>> loadMarkerData() async {
  final prefs = await SharedPreferences.getInstance();

  final String? markers = prefs.getString('markers');

  if (markers == null) {
    return {}; // No markers saved, therefore no data to load
  }

  Map<LatLng, MarkerData> markerData = {};

  for (LatLng point in parsePoints(markers)) {
    final String? data = prefs.getString(pointToString(point));
    if (data != null) {
      markerData[point] = MarkerData.fromString(data);
    } else {
      markerData[point] = MarkerData.empty(point);
    }
  }

  return markerData;
}

Future<List<Marker>> loadMarkers(Marker Function(LatLng) createMarker) async {
  final prefs = await SharedPreferences.getInstance();

  final String? markersData = prefs.getString('markers');

  if (markersData == null) {
    return [];
  }

  return parsePoints(markersData).map(createMarker).toList();
}

Future<List<Polyline>> loadPolylines(
    Polyline Function(List<LatLng>) createPolyline) async {
  final prefs = await SharedPreferences.getInstance();

  final String? polylinesData = prefs.getString('polylines');

  if (polylinesData == null) {
    return [];
  }

  return polylinesData.split('|').map(parsePoints).map(createPolyline).toList();
}

Future<void> saveMarkers(List<Marker> markers) async {
  final prefs = await SharedPreferences.getInstance();

  final String stringMarkers =
      pointsToString(markers.map((marker) => marker.point));

  await prefs.setString('markers', stringMarkers);
}

Future<void> savePolylines(List<Polyline> polylines) async {
  final prefs = await SharedPreferences.getInstance();

  final String stringPolylines = polylines
      .map((polyline) => polyline.points)
      .map(pointsToString)
      .join('|');

  await prefs.setString('polylines', stringPolylines);
}

Future<void> saveMarkerData(Map<LatLng, MarkerData> markerData) async {
  final prefs = await SharedPreferences.getInstance();

  markerData.forEach((point, data) {
    prefs.setString(pointToString(point), data.toString());
  });
}
