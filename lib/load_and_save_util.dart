import 'package:latlong2/latlong.dart';

String pointToString(LatLng point) => '${point.latitude},${point.longitude}';

LatLng pointFromString(String text) {
  final List<String> latLng = text.split(',');
  return LatLng(double.parse(latLng[0]), double.parse(latLng[1]));
}

String dateToString(DateTime date) => date.toString().split(' ')[0];
