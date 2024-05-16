import 'dart:async';

import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService extends ChangeNotifier {
  StreamSubscription? locationStream;
  LatLng? previousLocation;
  LatLng? currentLocation;

  LocationService(BuildContext context) {
    startListening(_listenerCallback, context);
    getLastKnownPosition().then(_listenerCallback);
  }

  void _listenerCallback(LatLng? position) {
    previousLocation = currentLocation;
    currentLocation = position;
    notifyListeners();
  }

  Future<void> checkPermissions(BuildContext context, bool showPopup) async {
    print('Checking Permission');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showPopup) {
        _showLocationServiceDialog(context);
      }
      print('Service not enabled');
      return; // Exit if location services are not enabled even after prompt.
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (showPopup) {
          _showPermissionRequestDialog(context);
        }
        print('Permissions not granted');
        return; // Exit if permissions are not granted.
      }
    }
    print('All Permissions granted');
  }

  Future<LatLng?> getLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) {
      return null;
    }
    return toLatLng(position);
  }

  Future<LatLng?> getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      return toLatLng(position);
    } catch (e) {
      return null;
    }
  }

  void startListening(Function(LatLng) onUpdate, BuildContext context) async {
    // Ensure that location service is enabled and permissions are granted.
    await checkPermissions(context, false);

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    locationStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .map(toLatLng)
            .listen(onUpdate);
  }

  void stopListening() {
    locationStream?.cancel(); // Stop listening to location changes
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  LatLng toLatLng(Position position) =>
      LatLng(position.latitude, position.longitude);

  void _showLocationServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Service Disabled"),
          content: const Text("Please enable location services."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Settings"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text(
              "This app needs location permissions to function properly."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Settings"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  void _openAppSettings() async {
    if (!await launchUrl(Uri.parse('app-settings:'))) {
      print('Could not open the app settings.');
    }
  }

  void _openLocationSettings() async {
    if (!await launchUrl(Uri.parse('package:settings'))) {
      print('Could not open the location settings.');
    }
  }
}
