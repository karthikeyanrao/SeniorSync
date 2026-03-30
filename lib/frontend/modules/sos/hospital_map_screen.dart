import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:seniorsync/frontend/modules/shared/senior_styles.dart';

class HospitalMapScreen extends StatefulWidget {
  const HospitalMapScreen({super.key});

  @override
  State<HospitalMapScreen> createState() => _HospitalMapScreenState();
}

class _HospitalMapScreenState extends State<HospitalMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<Marker> _hospitalMarkers = [];
  bool _isLoading = true;
  String _statusMessage = "Finding your location...";

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Location permissions denied.";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = LatLng(position.latitude, position.longitude);

      setState(() => _statusMessage = "Searching for nearby hospitals...");
      await _fetchNearbyHospitals();

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error: $e";
        });
      }
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> _fetchNearbyHospitals() async {
    if (_currentPosition == null) return;
    final lat = _currentPosition!.latitude;
    final lon = _currentPosition!.longitude;

    // OpenStreetMap Overpass API (Finds hospitals within 10,000 meters)
    final query = '[out:json];node(around:10000,$lat,$lon)[amenity=hospital];out;';
    final url = Uri.parse('https://overpass-api.de/api/interpreter?data=$query');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        List<Marker> markers = [];
        
        // Add current location marker
        markers.add(
          Marker(
            point: _currentPosition!,
            width: 80,
            height: 80,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.person_pin_circle, color: SeniorStyles.primaryBlue, size: 50),
          ),
        );

        for (var element in elements) {
          if (element['type'] == 'node') {
            final hLat = element['lat'];
            final hLon = element['lon'];
            final tags = element['tags'] ?? {};
            final name = tags['name'] ?? 'Hospital / Clinic';

            markers.add(
              Marker(
                point: LatLng(hLat, hLon),
                width: 60,
                height: 60,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => _showHospitalDetails(name, hLat, hLon),
                  child: const Icon(Icons.local_hospital, color: SeniorStyles.alertRed, size: 40),
                ),
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _hospitalMarkers = markers;
          });
          if (elements.isEmpty) {
            _statusMessage = "No hospitals found within 10km.";
          }
        }
      }
    } catch (e) {
      print("Error fetching hospitals: $e");
    }
  }

  void _showHospitalDetails(String name, double lat, double lon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: SeniorStyles.alertRed, size: 36),
                const SizedBox(width: 16),
                Expanded(child: Text(name, style: SeniorStyles.header, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openInGoogleMaps(lat, lon);
                },
                icon: const Icon(Icons.directions),
                label: const Text("Get Directions", style: SeniorStyles.largeButtonText),
                style: ElevatedButton.styleFrom(backgroundColor: SeniorStyles.primaryBlue, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double lat, double lon) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open maps.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeniorStyles.backgroundGray,
      appBar: AppBar(
        title: const Text("Nearby Hospitals", style: SeniorStyles.header),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(_statusMessage, style: SeniorStyles.subheader, textAlign: TextAlign.center),
                ],
              ),
            )
          : _currentPosition == null
              ? Center(child: Text(_statusMessage, style: const TextStyle(fontSize: 18, color: Colors.black54)))
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 13.0,
                        backgroundColor: Colors.white,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.seniorsync',
                        ),
                        MarkerLayer(
                          markers: _hospitalMarkers,
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: FloatingActionButton(
                        backgroundColor: SeniorStyles.primaryBlue,
                        child: const Icon(Icons.my_location, color: Colors.white),
                        onPressed: () {
                          _mapController.move(_currentPosition!, 14.0);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
