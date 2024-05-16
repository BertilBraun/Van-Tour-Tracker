import 'package:latlong2/latlong.dart';

import 'package:helloworld/load_and_save_util.dart';

class Route {
  final LatLng origin, destination;
  final List<LatLng> coordinates;
  final double distance;

  Route(
    this.origin,
    this.destination,
    this.coordinates,
    this.distance,
  );

  Map<String, dynamic> toMap() => {
        'origin': pointToString(origin),
        'destination': pointToString(destination),
        'coordinates': coordinates.map(pointToString).toList(),
        'distance': distance,
      };

  static Route fromMap(Map<String, dynamic> data) => Route(
        pointFromString(data['origin']),
        pointFromString(data['destination']),
        List<String>.from(data['coordinates']).map(pointFromString).toList(),
        data['distance'],
      );
}
