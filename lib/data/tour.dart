import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'package:helloworld/data/marker.dart';
import 'package:helloworld/data/route.dart';
import 'package:helloworld/load_and_save_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Tour {
  String name;
  List<LatLng> ordering;
  Map<LatLng, Marker> markers;
  List<Route> routes;

  Tour(this.name, this.ordering, this.markers, this.routes);
  static Tour empty({String name = DEFAULT_SAVE_NAME}) =>
      Tour(name, [], {}, []);

  int markerIndex(LatLng position) =>
      ordering.indexWhere((point) => point == position);

  Marker markerDataByIndex(int index) => markers[ordering[index]]!;

  Map<String, dynamic> toMap() => {
        _NAME_KEY: name,
        _ORDERING_KEY: ordering.map(pointToString).toList(),
        _MARKERS_KEY: markers
            .map((key, value) => MapEntry(pointToString(key), value.toMap())),
        _ROUTES_KEY: routes.map((route) => route.toMap()).toList(),
      };

  static Tour fromMap(Map<String, dynamic> data) => Tour(
        data[_NAME_KEY],
        List<String>.from(data[_ORDERING_KEY])
            .map((point) => pointFromString(point))
            .toList(),
        Map<String, dynamic>.from(data[_MARKERS_KEY]).map((key, value) =>
            MapEntry(pointFromString(key), Marker.fromMap(value))),
        List<dynamic>.from(data[_ROUTES_KEY])
            .map((route) => Route.fromMap(Map<String, dynamic>.from(route)))
            .toList(),
      );

  static Future<Tour> load(String saveName) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(saveName);

    Map<String, dynamic> appData;

    if (jsonData != null) {
      appData = jsonDecode(jsonData);
    } else {
      appData = {
        _NAME_KEY: DEFAULT_SAVE_NAME,
        _ORDERING_KEY: [],
        _MARKERS_KEY: {},
        _ROUTES_KEY: [],
      };
    }

    return Tour.fromMap(appData);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(name, jsonEncode(toMap()));
  }

  static const _NAME_KEY = 'name';
  static const _ORDERING_KEY = 'ordering';
  static const _MARKERS_KEY = 'markers';
  static const _ROUTES_KEY = 'routes';
  static const DEFAULT_SAVE_NAME = 'Current Tour';
}
