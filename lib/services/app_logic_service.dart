import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:helloworld/data/marker_data.dart';
import 'package:helloworld/data/app_data.dart';
import 'package:helloworld/data/route_data.dart';

import 'package:helloworld/services/routing_service.dart';

class AppLogicService extends ChangeNotifier {
  AppData appData = AppData.empty();
  int markerInsertIndex = -1;
  bool isFetchingRoute = false;

  AppLogicService() {
    loadData();
  }

  Future<void> loadData() async {
    appData = await AppData.load();
    _afterAppDataUpdate();
  }

  Future<void> saveData() => appData.save();

  Future<void> addMarker(LatLng position) async {
    if (isFetchingRoute) {
      return; // Dont allow adding another marker while the first one is loading
    }

    // first add the markerData to the map, as createMarker accesses that information
    appData.markers[position] = MarkerData.empty(position);

    if (markerInsertIndex == -1) {
      await _addMarkerAtEnd(position);
    } else {
      await _addMarkerAtInsertIndex(position);
    }

    _afterAppDataUpdate();
  }

  Future<void> onDelete(LatLng position) async {
    final int index = appData.markerIndex(position);

    List<Route> updatedRoutes = List.from(appData.routes);
    updatedRoutes.removeWhere((route) => route.coordinates.contains(position));

    if (index > 0 && index + 1 < appData.ordering.length) {
      // Recalculate polyline between the two markers adjacent to the removed marker
      final LatLng origin = appData.ordering[index - 1];
      final LatLng destination = appData.ordering[index + 1];
      updatedRoutes.add(await _fetchRoute(origin, destination));
    }

    appData.ordering.removeAt(index);
    appData.markers.remove(position);
    appData.routes = updatedRoutes;

    _afterAppDataUpdate();
  }

  void onUpdate(LatLng position, MarkerData newData) {
    appData.markers[position] = newData;
    _afterAppDataUpdate();
  }

  void onSelectAfter(LatLng position) {
    markerInsertIndex = appData.markerIndex(position);
    // Sentinel. If the markerInstertIndex is the last marker then it is the same as if no insert marker is selceted. This makes edge cases in the adding of new markers easier.
    if (markerInsertIndex == appData.ordering.length - 1) {
      markerInsertIndex = -1;
    }
  }

  Future<void> exportToCanva() async {
    // TODO export to something like canva with print ready
    // Calculate Bounding Box for each day, zoom map to fit, make screenshot, add statistics like traveled distance on that day, summarize all the descriptions and points of the markers on that day
    // Then generate a double page with all that data for the day
    // Generate some printable format with all the pages of the days
    //
    // Maybe use GPT to generate a nice description for each day
    // Maybe use some generative art to create a cover
  }

  void _afterAppDataUpdate() {
    notifyListeners();
    saveData();
  }

  void _setFetchingRoute(bool fetching) {
    isFetchingRoute = fetching;
    notifyListeners();
  }

  Future<void> _addMarkerAtEnd(LatLng position) async {
    appData.ordering.add(position);

    if (appData.ordering.length < 2) {
      return; // Not enough markers to create a route
    }

    // connect the last two markers with a route
    final LatLng origin = appData.ordering[appData.ordering.length - 2];
    final LatLng destination = appData.ordering[appData.ordering.length - 1];

    await _fetchAndAddRoute(origin, destination);
  }

  Future<void> _addMarkerAtInsertIndex(LatLng position) async {
    final LatLng originalStart = appData.ordering[markerInsertIndex];
    final LatLng originalEnd = appData.ordering[markerInsertIndex + 1];

    // remove the original connection where we want to insert the marker in between
    appData.routes.removeWhere((route) =>
        route.coordinates.contains(originalStart) &&
        route.coordinates.contains(originalEnd));

    // insert the marker at the appropriate position
    appData.ordering.insert(markerInsertIndex + 1, position);

    // add the two connections to the old markers
    await _fetchAndAddRoute(originalStart, position);
    await _fetchAndAddRoute(position, originalEnd);
    // next insert will be after the currently inserted marker
    markerInsertIndex++;
  }

  Future<AppData> _fetchAndAddRoute(LatLng origin, LatLng destination) async {
    appData.routes.add(await _fetchRoute(origin, destination));
    return appData;
  }

  Future<Route> _fetchRoute(LatLng origin, LatLng destination) async {
    _setFetchingRoute(true);
    final route = await RoutingService.fetchRoute(origin, destination);
    _setFetchingRoute(false);
    return route;
  }
}
