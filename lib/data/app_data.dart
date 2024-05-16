import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'package:helloworld/data/marker_data.dart';
import 'package:helloworld/data/route_data.dart';
import 'package:helloworld/load_and_save_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppData {
  static const _ORDERING_KEY = 'ordering';
  static const _MARKERS_KEY = 'markers';
  static const _ROUTES_KEY = 'routes';
  static const _DEFAULT_SAVE_NAME = 'appData';

  List<LatLng> ordering;
  Map<LatLng, MarkerData> markers;
  List<Route> routes;

  AppData(this.ordering, this.markers, this.routes);
  static AppData empty() => AppData([], {}, []);

  int markerIndex(LatLng position) =>
      ordering.indexWhere((point) => point == position);

  MarkerData markerDataByIndex(int index) => markers[ordering[index]]!;

  Map<String, dynamic> toMap() => {
        _ORDERING_KEY: ordering.map(pointToString).toList(),
        _MARKERS_KEY: markers
            .map((key, value) => MapEntry(pointToString(key), value.toMap())),
        _ROUTES_KEY: routes.map((route) => route.toMap()).toList(),
      };

  static AppData fromMap(Map<String, dynamic> data) => AppData(
        (data[_ORDERING_KEY] as List<String>)
            .map((point) => pointFromString(point))
            .toList(),
        (data[_MARKERS_KEY] as Map<String, dynamic>).map((key, value) =>
            MapEntry(pointFromString(key), MarkerData.fromMap(value))),
        (data[_ROUTES_KEY] as List<Map<String, dynamic>>)
            .map((route) => Route.fromMap(route))
            .toList(),
      );

  static Future<AppData> load({String saveName = _DEFAULT_SAVE_NAME}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString(saveName);

    Map<String, dynamic> appData;

    if (jsonData != null) {
      appData = jsonDecode(jsonData);
    } else {
      appData = {_ORDERING_KEY: [], _MARKERS_KEY: {}, _ROUTES_KEY: []};
    }

    return AppData.fromMap(appData);
  }

  Future<void> save({String saveName = _DEFAULT_SAVE_NAME}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(saveName, jsonEncode(toMap()));
  }
}
