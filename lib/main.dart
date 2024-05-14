import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:helloworld/location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:helloworld/marker_dialog.dart';
import 'package:helloworld/marker_data.dart';
import 'package:helloworld/settings.dart';
import 'package:helloworld/load_and_save.dart';
import 'package:helloworld/route_fetching.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Van Vacation Tracker',
      home: MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<LatLng, MarkerData> markerData = HashMap();
  List<Marker> markers = [];
  List<Polyline> polylines = [];
  int markerInsertIndex = -1;
  bool isFetchingRoute = false;
  Marker? currentLocationMarker;
  final MapController mapController = MapController();
  final LocationService locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLocationListener();
  }

  @override
  void dispose() {
    locationService.stopListening();
    super.dispose();
  }

  void _startLocationListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      locationService.startListening(
        (loc) {
          if (currentLocationMarker == null) {
            // Only zoom to current location with the first location update
            mapController.move(loc, 10);
          }
          setState(() {
            currentLocationMarker = Marker(
              width: 40.0,
              height: 40.0,
              point: loc,
              child: const Icon(
                Icons.my_location,
                size: 30.0,
                color: Colors.black,
              ),
            );
          });
        },
        context,
      );
    });
  }

  Future<void> _loadData() async {
    // first parse the markerDatas so that they are available once the markers are created
    markerData = await loadMarkerData();

    final newMarkers = await loadMarkers(createMarker);
    final newPolylines = await loadPolylines(createPolyline);

    setState(() {
      markers = newMarkers;
      polylines = newPolylines;
    });
  }

  Future<void> _saveData() async {
    await saveMarkerData(markerData);
    await saveMarkers(markers);
    await savePolylines(polylines);
  }

  Polyline createPolyline(List<LatLng> points) => Polyline(
        points: points,
        strokeWidth: 4,
        color: points.length == 2
            ? Colors.grey
            : const Color.fromARGB(255, 74, 46, 0),
      );

  Marker createMarker(LatLng position) => Marker(
        point: position,
        child: IconButton(
          icon: Image.asset(markerData[position]!.assetFileForType),
          onPressed: () => showMarker(position),
        ),
        width: markerData[position]!.type == 2 ? 25 : 50,
        height: markerData[position]!.type == 2 ? 25 : 50,
      );

  Future<void> addMarker(LatLng position) async {
    if (isFetchingRoute) {
      return; // Dont allow adding another marker while the first one is loading
    }
    // first add the markerData to the map, as createMarker accesses that information
    markerData[position] = MarkerData.empty(position);
    final Marker newMarker = createMarker(position);

    if (markerInsertIndex == -1) {
      await addMarkerAtEnd(newMarker);
    } else {
      await addMarkerAtInsertIndex(newMarker, position);
    }
    _saveData();
  }

  Future<void> addMarkerAtInsertIndex(Marker marker, LatLng position) async {
    final LatLng originalStart = markers[markerInsertIndex].point;
    final LatLng originalEnd = markers[markerInsertIndex + 1].point;
    // remove the original connection where we want to insert the marker in between
    setState(() {
      polylines.removeWhere((line) =>
          line.points.contains(originalStart) &&
          line.points.contains(originalEnd));
      markers.insert(markerInsertIndex + 1, marker);
    });
    // add the two connections to the old markers
    await fetchAndAddPolyline(originalStart, position);
    await fetchAndAddPolyline(position, originalEnd);
    // next insert will be after the currently inserted marker
    markerInsertIndex++;
  }

  Future<void> addMarkerAtEnd(Marker marker) async {
    setState(() {
      markers.add(marker);
    });

    if (markers.length >= 2) {
      // connect the last two markers with a route
      final LatLng origin = markers[markers.length - 2].point;
      final LatLng destination = markers[markers.length - 1].point;

      await fetchAndAddPolyline(origin, destination);
    }
  }

  Future<void> fetchAndAddPolyline(LatLng origin, LatLng destination) async {
    final Polyline newPolyline = await fetchPolyline(origin, destination);
    setState(() {
      polylines.add(newPolyline);
    });
  }

  Future<Polyline> fetchPolyline(LatLng origin, LatLng destination) async {
    setFetchingRoute(true);
    final List<LatLng> points = await fetchRoute(origin, destination);
    setFetchingRoute(false);
    return createPolyline(points);
  }

  void setFetchingRoute(bool isFetching) {
    setState(() {
      isFetchingRoute = isFetching;
    });
  }

  int markerIndex(LatLng position) =>
      markers.indexWhere((element) => element.point == position);

  void showMarker(LatLng position) {
    showDialog(
      context: context,
      builder: (context) {
        return MarkerDialog(
          position: position,
          markerData: markerData[position]!,
          onUpdate: (newData) => onUpdate(position, newData),
          onDelete: () => onDelete(position),
          onSelectAfter: () => onSelectAfter(position),
        );
      },
    );
  }

  void onUpdate(LatLng position, MarkerData newData) {
    setState(() {
      markerData[position] = newData;
      markers[markerIndex(position)] = createMarker(position);
    });
    _saveData();
  }

  Future<void> onDelete(LatLng position) async {
    Navigator.pop(context); // Close the dialog

    final int index = markerIndex(position);
    final Marker removedMarker = markers[index];

    List<Polyline> updatedPolylines = List.from(polylines);
    updatedPolylines.removeWhere(
        (polyline) => polyline.points.contains(removedMarker.point));

    if (index > 0 && index + 1 < markers.length) {
      // Recalculate polyline between the two markers adjacent to the removed marker
      final LatLng origin = markers[index - 1].point;
      final LatLng destination = markers[index + 1].point;
      updatedPolylines.add(await fetchPolyline(origin, destination));
    }

    setState(() {
      markers.removeAt(index);
      polylines = updatedPolylines;
    });
    _saveData();
  }

  void onSelectAfter(LatLng position) {
    Navigator.pop(context);
    markerInsertIndex =
        markers.indexWhere((element) => element.point == position);
    // Sentinel. If the markerInstertIndex is the last marker then it is the same as if no insert marker is selceted. This makes edge cases in the adding of new markers easier.
    if (markerInsertIndex == markers.length - 1) {
      markerInsertIndex = -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Van Vacation Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(41.39, 2.16),
              initialZoom: 10.0,
              onTap: (_, pos) => addMarker(pos),
              interactionOptions: const InteractionOptions(
                // disable rotation by flipping of the rotation bit
                flags: InteractiveFlag.all ^ InteractiveFlag.rotate,
              ),
            ),
            mapController: mapController,
            children: [
              TileLayer(
                urlTemplate:
                    'https://maps.geoapify.com/v1/tile/osm-bright-smooth/{z}/{x}/{y}.png?apiKey=${GEOAPIFY_API_KEY}',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
              MarkerLayer(
                markers: currentLocationMarker == null
                    ? []
                    : [currentLocationMarker!],
              ),
            ],
          ),
          if (isFetchingRoute) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // TODO should be an export button
        onPressed: () async {
          await SharedPreferences.getInstance().then((value) => value.clear());
          setState(() {
            markerData = HashMap();
            markers = [];
            polylines = [];
          });
        },
        child: const Icon(Icons.delete),
      ),
    );
  }
}
