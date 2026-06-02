import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/app_state.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final AppState _appState = AppState();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    await _locationService.requestPermission();
    await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  LatLng get _currentLocation {
    if (_appState.currentLatitude != null && _appState.currentLongitude != null) {
      return LatLng(_appState.currentLatitude!, _appState.currentLongitude!);
    }
    if (_locationService.currentPosition != null) {
      return LatLng(
        _locationService.currentPosition!.latitude,
        _locationService.currentPosition!.longitude,
      );
    }
    return LatLng(LocationService.defaultLat, LocationService.defaultLng);
  }

  double get _searchRadius => _appState.searchRadius > 0 ? _appState.searchRadius : 5000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karte'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMap(),
    );
  }

  Widget _buildMap() {
    final center = _currentLocation;
    final radius = _searchRadius;
    final shopMarkers = _appState.filteredResults
        .where((shop) => shop.latitude != 0 && shop.longitude != 0)
        .map((shop) => Marker(
              point: LatLng(shop.latitude, shop.longitude),
              width: 32,
              height: 32,
              child: const Icon(Icons.store, color: Colors.redAccent, size: 28),
            ))
        .toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.nearby_shop_finder',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
              ),
            ),
            ...shopMarkers,
          ],
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: radius,
              useRadiusInMeter: true,
              color: Colors.blue.withAlpha(100),
              borderColor: Colors.blue,
              borderStrokeWidth: 2,
            ),
          ],
        ),
      ],
    );
  }
}
