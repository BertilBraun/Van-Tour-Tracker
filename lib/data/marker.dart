import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:helloworld/load_and_save_util.dart';

const List<String> ASSET_FILES_FOR_TYPES = [
  'assets/heart.png',
  'assets/sleep.png',
  'assets/dot.png'
];

class Marker {
  final LatLng position;
  String name;
  String description;
  DateTime dateOfVisit;
  // 0 = Heart
  // 1 = Sleep
  // 2 = dot
  int type;
  List<File> pics;

  Marker(
    this.position,
    this.name,
    this.description,
    this.dateOfVisit,
    this.type,
    this.pics,
  );

  String get assetFileForType => ASSET_FILES_FOR_TYPES[type];

  Map<String, dynamic> toMap() => {
        'location': pointToString(position),
        'name': name,
        'description': description,
        'date': dateOfVisit.toIso8601String(),
        'type': type,
        'pics': pics.map((file) => file.path).toList(),
      };

  static Marker fromMap(Map<String, dynamic> data) => Marker(
        pointFromString(data['location']),
        data['name'],
        data['description'],
        DateTime.parse(data['date']),
        data['type'],
        List<String>.from(data['pics']).map((path) => File(path)).toList(),
      );

  static Marker empty(LatLng position) => Marker(
        position,
        "No Name",
        "",
        DateTime.now(),
        0,
        [],
      );
}
