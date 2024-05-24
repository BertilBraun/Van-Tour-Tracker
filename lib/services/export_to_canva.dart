import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Route;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:latlong2/latlong.dart';
import 'package:screenshot/screenshot.dart';

import 'package:helloworld/settings.dart';
import 'package:helloworld/widgets/map.dart';
import 'package:helloworld/data/marker.dart';
import 'package:helloworld/data/tour.dart';
import 'package:helloworld/data/route.dart';
import 'package:helloworld/load_and_save_util.dart';

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

  @override
  String toString() => 'Amount of Markers:$amountOfMarkers\n'
      'Distance: $distance\n';
}

class Exporter {
  final Tour currentTour;
  final Map<DateTime, List<Marker>> markersByDate = {};
  final BuildContext context;

  Exporter(this.currentTour, this.context) {
    _populateMarkersByDate();
  }

  Future<String> exportTour() async {
    // extracts all the days in markersByDate and compile the final document

    // NOTE: in parallel is no longer possible, as the extraction requires to show a dialog, therefore the days have to be processed one by one
    // final Iterable<Future<DayExport>> pageFutures =
    //     markersByDate.keys.map(_extractDay);
    // final List<DayExport> pages = await Future.wait(pageFutures);

    final List<DateTime> dates = markersByDate.keys.toList();
    dates.sort((a, b) => a.compareTo(b));

    List<DayExport> pages = [];
    for (final date in dates) {
      pages.add(await _extractDay(date));
    }

    // Compile all pages into a final document
    return await _compileFinalDocument(pages);
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

  Future<DayExport> _extractDay(DateTime date) async {
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
  ) =>
      // A route is of a given day, if it was reached as the destination at that day
      allRoutes
          .where((route) => dailyMarkers
              .any((marker) => marker.position == route.destination))
          .toList();

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
    final Uint8List imageBytes = await _createScreenshot(
      date,
      dailyMarkers,
      allRoutes,
      dailyRoutes,
    );

    final result = await ImageGallerySaver.saveImage(
      imageBytes,
      name: 'screenshot_day_${dateToString(date)}',
    );

    return File(result['filePath']!);
  }

  Future<Uint8List> _createScreenshot(
    DateTime date,
    List<Marker> dailyMarkers,
    List<Route> allRoutes,
    List<Route> dailyRoutes,
  ) async {
    const MAP_SIZE = (2000.0, 2000.0);

    final List<LatLng> allPointsOfTheDay = dailyRoutes
        .map((route) => route.coordinates)
        .reduce((all, coords) => all + coords)
        .toList();
    final LatLngBounds bounds = LatLngBounds.fromPoints(allPointsOfTheDay);
    final double zoom = _calculateZoomLevel(bounds, MAP_SIZE);

    final notDailyPolylines = allRoutes
        .where((route) => !dailyRoutes.contains(route))
        .map((route) => createPolyline(route.coordinates, Colors.grey))
        .toList();
    final dailyPolylines = dailyRoutes
        .map((route) => createPolyline(route.coordinates, ROUTE_COLOR))
        .toList();

    final mapWidget = MapWidget(
      markers: dailyMarkers.map((marker) => createMarker(marker, () {})),
      polylines: notDailyPolylines + dailyPolylines,
      onTap: (pos) {},
      initialCenter: bounds.center,
      initialZoom: zoom,
    );

    final ScreenshotController screenshotController = ScreenshotController();

    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => Center(
        child: Stack(
          children: [
            Positioned.fill(
              child: Screenshot(
                controller: screenshotController,
                child: mapWidget,
              ),
            ),
            // Transparent overlay to grey out the background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.2),
            ),
            // Progress text
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Please Wait...\n\nCurrently processing ${dateToString(date)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final imageBytes = await screenshotController.capture(
      delay: const Duration(seconds: 1),
    );

    Navigator.pop(context);

    return imageBytes!;
  }

  double _calculateZoomLevel(LatLngBounds bounds, (double, double) mapSize) {
    const double WORLD_DIM = 2048; // Default tile size in pixels
    const double ZOOM_MAX = 21; // Maximum zoom level

    double latRad(double lat) {
      double sinLat = sin(lat * pi / 180);
      double radX2 = log((1 + sinLat) / (1 - sinLat)) / 2;
      return max(min(radX2, pi), -pi) / 2;
    }

    double zoom(double mapPx, double worldPx, double fraction) {
      return (log(mapPx / worldPx / fraction) / ln2).clamp(0, ZOOM_MAX);
    }

    double latFraction = (latRad(bounds.north) - latRad(bounds.south)) / pi;
    double lngFraction = ((bounds.east - bounds.west) + 360) % 360 / 360;

    final (mapWidth, mapHeight) = mapSize;

    double latZoom = zoom(mapHeight, WORLD_DIM, latFraction);
    double lngZoom = zoom(mapWidth, WORLD_DIM, lngFraction);

    return min(latZoom, lngZoom);
  }

  // Compile all daily pages into a final document
  Future<String> _compileFinalDocument(List<DayExport> pages) async {
    // TODO export to something like canva with print ready
    //
    // Then generate a double page with all that data for the day
    // Generate some printable format with all the pages of the days
    //
    // Maybe use GPT to generate a nice description for each day
    // Maybe use some generative art to create a cover

    pages.sort((a, b) => a.date.compareTo(b.date));

    final int totalDistance = pages
        .map((day) => day.distance)
        .reduce((sum, dist) => sum + dist)
        .floor();
    final DateTime startDay = pages.first.date;
    final DateTime endDay = pages.last.date;
    final int durationInDays = endDay.difference(startDay).inDays + 1;

    StringBuffer buffer = StringBuffer();

    buffer.write('Started on ${dateToString(startDay)}\n');
    buffer.write('Ended on ${dateToString(endDay)}\n');
    buffer.write('Traveled for $durationInDays days\n');
    buffer.write('With a total distance of $totalDistance meters\n');

    for (int i = 0; i < pages.length; i++) {
      buffer.write(
          'Day ${i + 1} (${dateToString(pages[i].date)}): ${pages[i]}\n\n');
    }

    return buffer.toString();
  }
}
