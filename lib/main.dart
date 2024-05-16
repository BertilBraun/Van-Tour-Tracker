import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'package:helloworld/settings.dart';
import 'package:helloworld/marker_dialog.dart';
import 'package:helloworld/settings_dialog.dart';

import 'package:helloworld/data/tour.dart';

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
    if (locationService.previousLocation == null &&
        locationService.currentLocation != null) {
      // If we just now found a location, then zoom the map to that location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(locationService.currentLocation!, 12);
        locationService.previousLocation = locationService.currentLocation;
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

    Polyline createPolyline(List<LatLng> points) => Polyline(
          points: points,
          strokeWidth: 4,
          color: points.length == 2
              ? Colors.grey
              : const Color.fromARGB(255, 74, 46, 0),
        );

    Marker createMarker(LatLng position) => Marker(
          key: ObjectKey(currentTour.markers[position]),
          point: position,
          child: IconButton(
            icon: Image.asset(currentTour.markers[position]!.assetFileForType),
            onPressed: () => showMarker(position),
          ),
          width: currentTour.markers[position]!.type == 2 ? 25 : 50,
          height: currentTour.markers[position]!.type == 2 ? 25 : 50,
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
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(41.39, 2.16),
              initialZoom: 10.0,
              onTap: (_, pos) => appLogic.addMarker(pos),
              interactionOptions: const InteractionOptions(
                // disable rotation by flipping of the rotation bit
                flags: InteractiveFlag.all ^ InteractiveFlag.rotate,
              ),
            ),
            mapController: mapController,
            children: [
              TileLayer(
                tileProvider: CancellableNetworkTileProvider(),
                //urlTemplate:
                urlTemplate:
                    'https://tile.jawg.io/jawg-terrain/{z}/{x}/{y}.png?access-token=$ACCESS_TOKEN',
                // 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                // 'https://maps.geoapify.com/v1/tile/osm-bright-smooth/{z}/{x}/{y}.png?apiKey=$GEOAPIFY_API_KEY',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(
                polylines: currentTour.routes
                    .map((route) => route.coordinates)
                    .map(createPolyline)
                    .toList(),
              ),
              MarkerLayer(
                markers: currentTour.ordering.map(createMarker).toList(),
              ),
              if (locationService.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: locationService.currentLocation!,
                      child: const Icon(
                        Icons.my_location,
                        size: 30.0,
                        color: Colors.black,
                      ),
                    )
                  ],
                ),
            ],
          ),
          if (appLogic.isFetchingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      backgroundColor: MAIN_COLOR,
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
