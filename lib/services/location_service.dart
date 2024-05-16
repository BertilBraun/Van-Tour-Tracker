import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class LocationService extends ChangeNotifier {
  final Location location = Location();
  Stream<LatLng>? locationStream;
  LatLng? previousLocation;
  LatLng? currentLocation;

  LocationService(BuildContext context) {
    startListening((loc) {
      previousLocation = currentLocation;
      currentLocation = loc;
      notifyListeners();
    }, context);
  }

  Future<void> checkPermissions(BuildContext context, bool showPopup) async {
    print('Checking Permission');

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        if (showPopup) {
          _showLocationServiceDialog(context);
        }
        print('Service not enabled');
        return; // Exit if location services are not enabled even after prompt.
      }
    }

    PermissionStatus permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        if (showPopup) {
          _showPermissionRequestDialog(context);
        }
        print('Permissions not granted');
        return; // Exit if permissions are not granted.
      }
    }
  }

  void startListening(Function(LatLng) onUpdate, BuildContext context) async {
    // Ensure that location service is enabled and permissions are granted.
    await checkPermissions(context, false);

    locationStream = location.onLocationChanged.map((locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        return LatLng(locationData.latitude!, locationData.longitude!);
      } else {
        throw Exception('Invalid location data');
      }
    });

    locationStream!.listen(onUpdate, onError: (error) {
      // Handle error or log it
      print('Location Stream Error: $error');
    });
  }

  void stopListening() {
    locationStream?.listen(null).cancel(); // Stop listening to location changes
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

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
