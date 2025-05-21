import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;

  const TripMapScreen({super.key, required this.tripId});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late GoogleMapController _mapController;
  final LatLng _initialPosition = const LatLng(37.7749, -122.4194);

  late Timer _timer;

  List<LatLng> _memberPositions = [];
  Set<Marker> _markers = {};

  Trip? _trip;

  @override
  void initState() {
    super.initState();

    // Initialize member positions with slight offsets
    _memberPositions = List.generate(
      5,
          (i) => LatLng(
        _initialPosition.latitude + i * 0.001,
        _initialPosition.longitude + i * 0.001,
      ),
    );

    // Initialize markers
    _updateMarkers();

    // Load trip data once, outside of build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tripService = Provider.of<TripService>(context, listen: false);
      final tripData = await tripService.getTrip(widget.tripId);

      setState(() {
        _trip = tripData;
      });
    });

    // Timer to update positions and markers every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      setState(() {
        _memberPositions = _memberPositions.map((pos) {
          return LatLng(pos.latitude + 0.0001, pos.longitude + 0.0001);
        }).toList();

        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueViolet,
    ];

    _markers = _memberPositions.asMap().entries.map((entry) {
      int idx = entry.key;
      LatLng pos = entry.value;

      return Marker(
        markerId: MarkerId('member$idx'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(hues[idx % hues.length]),
      );
    }).toSet();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convoy Trip')),
      body: _trip == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 12,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination: ${_trip!.destination}', style: const TextStyle(fontSize: 18)),
                Text('Members: ${_trip!.members.length}', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
