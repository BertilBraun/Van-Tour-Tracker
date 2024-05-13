import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';

import 'package:helloworld/marker_dialog.dart';
import 'package:helloworld/marker_data.dart';
import 'package:helloworld/util.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  bool isFetchingRoute = false;
  List<Marker> currentLocationMarkers = [];
  final MapController mapController = MapController();
  int markerInstertIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    final Location location = Location();
    PermissionStatus permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) {
        return;
      }
    }

    final LocationData currentLocation = await location.getLocation();

    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return;
    }

    final LatLng loc =
        LatLng(currentLocation.latitude!, currentLocation.longitude!);
    setState(() {
      mapController.move(loc, 10);
      currentLocationMarkers = [
        Marker(
          width: 40.0,
          height: 40.0,
          point: loc,
          child: const Icon(
            Icons.my_location,
            size: 30.0,
            color: Colors.black,
          ),
        )
      ];
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? markersData = prefs.getString('markers');
    final String? polylinesData = prefs.getString('polylines');

    if (markersData != null) {
      // first parse the markerDatas so that they are available once the markers are created
      parsePoints(markersData).forEach((point) {
        markerData[point] =
            MarkerData.fromString(prefs.getString(pointToString(point)) ?? '');
      });

      var newMarkers = parsePoints(markersData).map(createMarker).toList();

      setState(() {
        markers = newMarkers;
      });
    }

    if (polylinesData != null) {
      var newPolylines = polylinesData
          .split('|')
          .map(parsePoints)
          .map(createPolyline)
          .toList();
      setState(() {
        polylines = newPolylines;
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    String stringMarkers =
        markers.map((marker) => marker.point).map(pointToString).join(';');
    String stringPolylines = polylines
        .map((polyline) => polyline.points.map(pointToString).join(';'))
        .join('|'); // Use a different delimiter to separate each polyline

    markerData.forEach((point, data) {
      prefs.setString(pointToString(point), data.toString());
    });

    await prefs.setString('markers', stringMarkers);
    await prefs.setString('polylines', stringPolylines);
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
    // first add the markerData to the map, as createMarker accesses that information
    markerData[position] = MarkerData.empty(position);
    final Marker newMarker = createMarker(position);

    if (markerInstertIndex == -1) {
      setState(() {
        markers.add(newMarker);
      });

      if (markers.length >= 2) {
        // connect the last two markers with a route
        final LatLng origin = markers[markers.length - 2].point;
        final LatLng destination = markers[markers.length - 1].point;

        await fetchAndAddPolyline(origin, destination);
      }
    } else {
      final LatLng originalStart = markers[markerInstertIndex].point;
      final LatLng originalEnd = markers[markerInstertIndex + 1].point;
      // remove the original connection where we want to insert the marker in between
      setState(() {
        polylines.removeWhere((line) =>
            line.points.contains(originalStart) &&
            line.points.contains(originalEnd));
        markers.insert(markerInstertIndex + 1, newMarker);
      });
      // add the two connections to the old markers
      await fetchAndAddPolyline(originalStart, position);
      await fetchAndAddPolyline(position, originalEnd);
      markerInstertIndex++;
    }
    _saveData();
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
    markerInstertIndex =
        markers.indexWhere((element) => element.point == position);
    // Sentinel. If the markerInstertIndex is the last marker then it is the same as if no insert marker is selceted. This makes edge cases in the adding of new markers easier.
    if (markerInstertIndex == markers.length - 1) {
      markerInstertIndex = -1;
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
              MarkerLayer(markers: currentLocationMarkers),
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
