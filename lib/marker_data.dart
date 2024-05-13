import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:helloworld/util.dart';

const List<String> ASSET_FILES_FOR_TYPES = [
  'assets/heart.png',
  'assets/sleeping_sheep.png',
  'assets/dot.png'
];

class MarkerData {
  final LatLng position;
  String name;
  String description;
  DateTime dateOfVisit;
  // 0 = Heart
  // 1 = Sleep
  // 2 = dot
  int type;
  List<File> pics;

  MarkerData(
    this.position,
    this.name,
    this.description,
    this.dateOfVisit,
    this.type,
    this.pics,
  );

  String get assetFileForType => ASSET_FILES_FOR_TYPES[type];

  @override
  String toString() {
    return 'LOCATION: ${pointToString(position)}\n'
        'NAME: $name\n'
        'DESCRIPTION: $description\n'
        'DATE: ${dateOfVisit.toIso8601String()}\n'
        'TYPE: $type\n'
        'PICS: ${pics.map((e) => e.path).join(';')}';
  }

  static MarkerData fromString(String text) {
    if (text == '') return empty(const LatLng(0, 0));

    Map<String, String> data = {};
    final labels = [
      'LOCATION:',
      'NAME:',
      'DESCRIPTION:',
      'DATE:',
      'TYPE:',
      'PICS:'
    ];

    String? lastLabel;
    int start;
    for (var label in labels) {
      start = text.indexOf(label);
      if (start == -1) continue;
      if (lastLabel != null) {
        data[lastLabel] = text
            .substring(text.indexOf(lastLabel) + lastLabel.length, start)
            .trim();
      }
      lastLabel = label;
    }
    if (lastLabel != null) {
      data[lastLabel] =
          text.substring(text.indexOf(lastLabel) + lastLabel.length).trim();
    }

    if (!data.containsKey('LOCATION:') ||
        !data.containsKey('DATE:') ||
        !data.containsKey('PICS:')) {
      throw const FormatException('Missing data for LOCATION or DATE or PICS');
    }

    final location = parsePoint(data['LOCATION:']!);

    final dateOfVisit = DateTime.tryParse(data['DATE:']!);
    if (dateOfVisit == null) {
      throw const FormatException('Invalid date format');
    }

    final pics = data['PICS:']!
        .split(';')
        .where((path) => path.isNotEmpty)
        .map(File.new)
        .toList();

    return MarkerData(
      location,
      data['NAME:'] ?? '',
      data['DESCRIPTION:'] ?? '',
      dateOfVisit,
      int.tryParse(data['TYPE:'] ?? '') ?? 0,
      pics,
    );
  }

  static MarkerData empty(LatLng position) => MarkerData(
        position,
        "No Name",
        "",
        DateTime.now(),
        0,
        [],
      );
}
