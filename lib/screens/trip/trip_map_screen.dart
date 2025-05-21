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
  final LatLng _initialPosition = const LatLng(37.7749, -122.4194); // Default to San Francisco

  @override
  Widget build(BuildContext context) {
    final tripService = Provider.of<TripService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Convoy Trip')),
      body: FutureBuilder<Trip?>(
        future: tripService.getTrip(widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Trip not found'));
          }

          final trip = snapshot.data!;

          return Column(
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

                  markers: {
                    // Simulate convoy members with colored dots
                    Marker(
                      markerId: const MarkerId('member1'),
                      position: _initialPosition,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                    Marker(
                      markerId: const MarkerId('member2'),
                      position: LatLng(_initialPosition.latitude + 0.01, _initialPosition.longitude + 0.01),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                    Marker(
                      markerId: const MarkerId('member3'),
                      position: LatLng(_initialPosition.latitude - 0.01, _initialPosition.longitude - 0.01),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destination: ${trip.destination}', style: const TextStyle(fontSize: 18)),
                    Text('Members: ${trip.members.length}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}