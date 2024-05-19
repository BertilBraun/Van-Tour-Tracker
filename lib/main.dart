import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:helloworld/settings.dart';
import 'package:helloworld/marker_dialog.dart';
import 'package:helloworld/settings_dialog.dart';

import 'package:helloworld/data/tour.dart';

import 'package:helloworld/widgets/map.dart';

import 'package:helloworld/services/location_service.dart';
import 'package:helloworld/services/app_logic_service.dart';

void main() => runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppLogicService()),
        ChangeNotifierProvider(create: (context) => LocationService(context)),
      ],
      child: const MainApp(),
    ));

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLogicService appLogic = context.watch<AppLogicService>();
    final LocationService locationService = context.watch<LocationService>();

    return MaterialApp(
      title: 'Travel Tales',
      home: MapScreen(
        currentTour: appLogic.currentTour,
        appLogic: appLogic,
        locationService: locationService,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatelessWidget {
  final Tour currentTour;
  final AppLogicService appLogic;
  final LocationService locationService;

  MapScreen({
    super.key,
    required this.currentTour,
    required this.appLogic,
    required this.locationService,
  });

  final MapController mapController = MapController();

  @override
  Widget build(BuildContext context) {
    if (!appLogic.hasMovedToLocationOnceAlready &&
        locationService.currentLocation != null) {
      // If we just now found a location, then zoom the map to that location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(locationService.currentLocation!, 12);
        appLogic.hasMovedToLocation();
      });
    }

    void showMarker(LatLng position) => showDialog(
          context: context,
          builder: (context) {
            return MarkerDialog(
              position: position,
              marker: currentTour.markers[position]!,
              onUpdate: (newData) {
                appLogic.onUpdate(position, newData);
              },
              onDelete: () {
                Navigator.pop(context); // close the dialog
                appLogic.onDelete(position);
              },
              onSelectAfter: () {
                Navigator.pop(context); // close the dialog
                appLogic.onSelectAfter(position);
              },
            );
          },
        );

    return Scaffold(
      appBar: AppBar(
        leading: Image.asset('assets/icon.png'),
        title: const Text(
          'Travel Tales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: MAIN_COLOR,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MapWidget(
            polylines: currentTour.routes
                .map((route) => route.coordinates)
                .map((points) => createPolyline(points, ROUTE_COLOR)),
            markers: currentTour.markers.keys.map((position) => createMarker(
                  currentTour.markers[position]!,
                  () => showMarker(position),
                  sizeScaling: MapCamera.of(context).zoom < 9 ? 0.5 : 1.0,
                )),
            onTap: (pos) => appLogic.addMarker(pos),
            mapController: mapController,
            currentLocation: locationService.currentLocation,
          ),
          if (appLogic.isFetchingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      backgroundColor: MAIN_COLOR,
      persistentFooterAlignment: AlignmentDirectional.bottomCenter,
      persistentFooterButtons: [
        IconButton(
          onPressed: () async {
            if (locationService.currentLocation == null) {
              locationService.checkPermissions(context, true);
              locationService.currentLocation =
                  await locationService.getLocation();
            }

            if (locationService.currentLocation != null) {
              mapController.move(locationService.currentLocation!, 12);
            }
          },
          icon: const Icon(Icons.my_location),
        ),
        IconButton(
          onPressed: () => appLogic.exportToCanva(),
          icon: const Icon(Icons.print),
        ),
        IconButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => SettingsDialog(),
            );
          },
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }
}
