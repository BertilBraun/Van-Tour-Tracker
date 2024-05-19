import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as mat;
import 'package:flutter_map/flutter_map.dart' as map;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

import 'package:helloworld/settings.dart';
import 'package:helloworld/widgets/map.dart';
import 'package:helloworld/data/marker.dart';
import 'package:helloworld/data/tour.dart';
import 'package:helloworld/data/route.dart';

class DayExport {
  final DateTime date;
  final int amountOfMarkers;
  final double distance;
  final File routeImage;
  final List<Marker> markers;

  DayExport(
    this.date,
    this.amountOfMarkers,
    this.distance,
    this.routeImage,
    this.markers,
  );
}

class Exporter {
  final Tour currentTour;
  final Map<DateTime, List<Marker>> markersByDate = {};

  Exporter(this.currentTour) {
    _populateMarkersByDate();
  }

  void _populateMarkersByDate() {
    // first insert all non stopover markers
    final Iterable<Marker> nonStopoverMarkers =
        currentTour.markers.values.where((marker) => !marker.isStopover);
    for (final marker in nonStopoverMarkers) {
      final DateTime date = marker.dateOnlyOfVisit;
      if (markersByDate.containsKey(date)) {
        markersByDate[date]!.add(marker);
      } else {
        markersByDate[date] = [marker];
      }
    }

    // Stopovers should automatically match with the date to the date of the first not stopover point after the stopover point
    final Iterable<Marker> stopoverMarkers =
        currentTour.markers.values.where((marker) => marker.isStopover);
    for (final marker in stopoverMarkers) {
      Marker? firstNonStopoverMarkerAfter =
          _getFirstNonStopoverMarkerAfter(marker);
      if (firstNonStopoverMarkerAfter == null) {
        print('Warning: Last Marker seems to have been a stopover marker');
        continue;
      }
      // entry must exist, since the non stopover marker was already added to that list
      markersByDate[firstNonStopoverMarkerAfter.dateOnlyOfVisit]!.add(marker);
    }
  }

  Marker? _getFirstNonStopoverMarkerAfter(Marker marker) {
    Marker? markerAfter = _getMarkerAfterMarker(marker);
    while (markerAfter != null && markerAfter.isStopover) {
      markerAfter = _getMarkerAfterMarker(markerAfter);
    }
    return markerAfter;
  }

  Marker? _getMarkerAfterMarker(Marker marker) {
    try {
      Route route = currentTour.routes
          .firstWhere((route) => route.origin == marker.position);
      return currentTour.markers.entries
          .firstWhere((entry) => entry.key == route.destination)
          .value;
    } on StateError {
      return null;
    }
  }

  Future<void> exportTour() async {
    // extracts all the days in markersByDate in parallel and compile the final document
    final Iterable<Future<DayExport>> pageFutures =
        markersByDate.keys.map(extractDay);

    final List<DayExport> pages = await Future.wait(pageFutures);

    // Compile all pages into a final document
    await _compileFinalDocument(pages);
  }

  Future<DayExport> extractDay(DateTime date) async {
    final List<Marker> dailyMarkers = markersByDate[date]!;
    final List<Route> dailyRoutes =
        _calculateDailyRoutes(currentTour.routes, dailyMarkers);

    final double dailyDistance = _calculateTotalDistance(dailyRoutes);

    final File routeImage = await _makeScreenshot(
      date,
      dailyMarkers,
      currentTour.routes,
      dailyRoutes,
    );

    return DayExport(
      date,
      dailyMarkers.where((marker) => !marker.isStopover).length,
      dailyDistance,
      routeImage,
      dailyMarkers,
    );
  }

  // Calculate daily routes from all routes and markers
  List<Route> _calculateDailyRoutes(
    List<Route> allRoutes,
    List<Marker> dailyMarkers,
  ) {
    // A route is of a given day, if it was reached as the destination at that day
    return allRoutes
        .where((route) =>
            dailyMarkers.any((marker) => marker.position == route.destination))
        .toList();
  }

  // Calculate total distance for the day
  double _calculateTotalDistance(List<Route> dailyRoutes) {
    double totalDistance = 0.0;
    for (final route in dailyRoutes) {
      totalDistance += route.distance;
    }
    return totalDistance;
  }

  Future<File> _makeScreenshot(
    DateTime date,
    List<Marker> dailyMarkers,
    List<Route> allRoutes,
    List<Route> dailyRoutes,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/screenshot_day_$date.png';

    final imageBytes = await _createScreenshot(
      dailyMarkers,
      allRoutes,
      dailyRoutes,
    );

    final File imageFile = File(imagePath);
    await imageFile.writeAsBytes(imageBytes);

    return imageFile;
  }

  Future<Uint8List> _createScreenshot(
    List<Marker> dailyMarkers,
    List<Route> allRoutes,
    List<Route> dailyRoutes,
  ) async {
    final List<LatLng> allPointsOfTheDay = dailyRoutes
        .map((route) => route.coordinates)
        .reduce((list, coords) => list + coords)
        .toList();

    final map.CenterZoom centerZoom = map.MapController()
        .centerZoomFitBounds(map.LatLngBounds.fromPoints(allPointsOfTheDay));

    final List<map.Polyline> notDailyPolylines = allRoutes
        .where((route) => !dailyRoutes.contains(route))
        .map((route) => createPolyline(route.coordinates, mat.Colors.grey))
        .toList();
    final List<map.Polyline> dailyPolylines = dailyRoutes
        .map((route) => createPolyline(route.coordinates, ROUTE_COLOR))
        .toList();

    final mapWidget = MapWidget(
      markers: dailyMarkers.map((marker) => createMarker(marker, () {})),
      polylines: notDailyPolylines + dailyPolylines,
      onTap: (pos) {},
      initialCenter: centerZoom.center,
      initialZoom: centerZoom.zoom,
    );

    Uint8List imageBytes = await ScreenshotController().captureFromWidget(
      mapWidget,
      delay: const Duration(seconds: 1), // Add delay to allow map tiles to load
    );

    return imageBytes;
  }

  // Compile all daily pages into a final document
  Future<void> _compileFinalDocument(List<DayExport> pages) async {
    // TODO export to something like canva with print ready
    //
    // Then generate a double page with all that data for the day
    // Generate some printable format with all the pages of the days
    //
    // Maybe use GPT to generate a nice description for each day
    // Maybe use some generative art to create a cover

    pages.sort((a, b) => a.date.compareTo(b.date));

    final double totalDistance =
        pages.map((day) => day.distance).reduce((sum, dist) => sum + dist);
    final DateTime startDay = pages.first.date;
    final DateTime endDay = pages.last.date;
    final int durationInDays = endDay.difference(startDay).inDays;

    print('Started on $startDay');
    print('Ended on $endDay');
    print('Traveled for $durationInDays days');
    print('With a total distance of $totalDistance');

    for (int i = 0; i < pages.length; i++) {
      print('Day ${i + 1} (${pages[i].date}): ${pages[i]}');
    }
  }
}
