import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import 'package:helloworld/settings.dart';

import 'package:helloworld/data/marker.dart' as data;

Polyline createPolyline(List<LatLng> points, Color lineColor) => Polyline(
      points: points,
      strokeWidth: 4,
      color: points.length == 2 ? Colors.grey : lineColor,
    );

Marker createMarker(
  data.Marker markerData,
  Function() onPressed, {
  double sizeScaling = 1.0,
}) {
  final size = (markerData.isStopover ? 25 : 50) * sizeScaling;
  return Marker(
    point: markerData.position,
    child: IconButton(
      icon: Image.asset(markerData.assetFileForType),
      onPressed: onPressed,
    ),
    width: size,
    height: size,
  );
}

class MapWidget extends StatelessWidget {
  const MapWidget({
    super.key,
    required this.polylines,
    required this.markers,
    required this.onTap,
    this.mapController,
    this.currentLocation,
    this.initialCenter = const LatLng(41.39, 2.16), // Barcelona
    this.initialZoom = 10.0,
  });

  final Iterable<Polyline> polylines;
  final Iterable<Marker> markers;

  final Function(LatLng) onTap;

  final MapController? mapController;
  final LatLng? currentLocation;

  final LatLng initialCenter;
  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        minZoom: 7,
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onTap: (_, pos) => onTap(pos),
        interactionOptions: const InteractionOptions(
          // disable rotation by flipping of the rotation bit
          flags: InteractiveFlag.all ^ InteractiveFlag.rotate,
        ),
      ),
      mapController: mapController,
      children: [
        TileLayer(
          tileProvider: CancellableNetworkTileProvider(),
          urlTemplate:
              'https://tile.jawg.io/jawg-terrain/{z}/{x}/{y}.png?access-token=$ACCESS_TOKEN',
          // 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
          // 'https://maps.geoapify.com/v1/tile/osm-bright-smooth/{z}/{x}/{y}.png?apiKey=$GEOAPIFY_API_KEY',
          userAgentPackageName: 'com.example.app',
        ),
        PolylineLayer(polylines: polylines.toList()),
        MarkerLayer(markers: markers.toList()),
        if (currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                width: 40.0,
                height: 40.0,
                point: currentLocation!,
                child: const Icon(
                  Icons.my_location,
                  size: 30.0,
                  color: Colors.black,
                ),
              )
            ],
          ),
      ],
    );
  }
}
