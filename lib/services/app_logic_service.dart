import 'package:flutter/foundation.dart';
import 'package:helloworld/data/current_state.dart';
import 'package:latlong2/latlong.dart';

import 'package:helloworld/data/marker.dart';
import 'package:helloworld/data/tour.dart';
import 'package:helloworld/data/route.dart';

import 'package:helloworld/services/routing_service.dart';
import 'package:helloworld/services/export_to_canva.dart';

class AppLogicService extends ChangeNotifier {
  CurrentState currentState = CurrentState.empty();

  Tour currentTour = Tour.empty();
  int markerInsertIndex = -1;
  bool isFetchingRoute = false;
  bool hasMovedToLocationOnceAlready = false;

  AppLogicService() {
    loadData();
  }

  Future<void> loadData() async {
    currentState = await CurrentState.load();
    currentTour = await Tour.load(currentState.currentTourName);
    _afterAppDataUpdate();
  }

  Future<void> saveData() =>
      currentTour.save().then((value) => currentState.save());

  Future<void> addMarker(LatLng position) async {
    if (isFetchingRoute) {
      return; // Dont allow adding another marker while the first one is loading
    }

    // first add the markerData to the map, as createMarker accesses that information
    currentTour.markers[position] = Marker.empty(position);

    if (markerInsertIndex == -1) {
      await _addMarkerAtEnd(position);
    } else {
      await _addMarkerAtInsertIndex(position);
    }

    _afterAppDataUpdate();
  }

  Future<void> onDelete(LatLng position) async {
    final int index = currentTour.markerIndex(position);

    List<Route> updatedRoutes = List.from(currentTour.routes);
    updatedRoutes.removeWhere((route) => route.coordinates.contains(position));

    if (index > 0 && index + 1 < currentTour.ordering.length) {
      // Recalculate polyline between the two markers adjacent to the removed marker
      final LatLng origin = currentTour.ordering[index - 1];
      final LatLng destination = currentTour.ordering[index + 1];
      updatedRoutes.add(await _fetchRoute(origin, destination));
    }

    currentTour.ordering.removeAt(index);
    currentTour.markers.remove(position);
    currentTour.routes = updatedRoutes;

    _afterAppDataUpdate();
  }

  void onUpdate(LatLng position, Marker newData) {
    currentTour.markers[position] = newData;
    _afterAppDataUpdate();
  }

  void onSelectAfter(LatLng position) {
    markerInsertIndex = currentTour.markerIndex(position);
    // Sentinel. If the markerInstertIndex is the last marker then it is the same as if no insert marker is selceted. This makes edge cases in the adding of new markers easier.
    if (markerInsertIndex == currentTour.ordering.length - 1) {
      markerInsertIndex = -1;
    }
  }

  Future<String> exportToCanva() => Exporter(currentTour).exportTour();

  void hasMovedToLocation() {
    hasMovedToLocationOnceAlready = true;
    notifyListeners();
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
    currentTour.ordering.add(position);

    if (currentTour.ordering.length < 2) {
      return; // Not enough markers to create a route
    }

    // connect the last two markers with a route
    final LatLng origin = currentTour.ordering[currentTour.ordering.length - 2];
    final LatLng destination =
        currentTour.ordering[currentTour.ordering.length - 1];

    await _fetchAndAddRoute(origin, destination);
  }

  Future<void> _addMarkerAtInsertIndex(LatLng position) async {
    final LatLng originalStart = currentTour.ordering[markerInsertIndex];
    final LatLng originalEnd = currentTour.ordering[markerInsertIndex + 1];

    // remove the original connection where we want to insert the marker in between
    currentTour.routes.removeWhere((route) =>
        route.coordinates.contains(originalStart) &&
        route.coordinates.contains(originalEnd));

    // insert the marker at the appropriate position
    currentTour.ordering.insert(markerInsertIndex + 1, position);

    // add the two connections to the old markers
    await _fetchAndAddRoute(originalStart, position);
    await _fetchAndAddRoute(position, originalEnd);
    // next insert will be after the currently inserted marker
    markerInsertIndex++;
  }

  Future<Tour> _fetchAndAddRoute(LatLng origin, LatLng destination) async {
    currentTour.routes.add(await _fetchRoute(origin, destination));
    return currentTour;
  }

  Future<Route> _fetchRoute(LatLng origin, LatLng destination) async {
    _setFetchingRoute(true);
    final route = await RoutingService.fetchRoute(origin, destination);
    _setFetchingRoute(false);
    return route;
  }
}
