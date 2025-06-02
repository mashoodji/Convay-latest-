import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;
  final String currentUserId;

  const TripMapScreen({
    super.key,
    required this.tripId,
    required this.currentUserId,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _currentLocation;
  double _distance = 0.0;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _tripSubscription;
  StreamSubscription? _membersSubscription;

  @override
  void initState() {
    super.initState();
    _setupLocationUpdates();
    _listenToTripUpdates();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _tripSubscription?.cancel();
    _membersSubscription?.cancel();
    super.dispose();
  }

  void _setupLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = newLocation);

      // Update member location in Firestore
      await Provider.of<TripService>(context, listen: false).updateMemberLocation(
        tripId: widget.tripId,
        userId: widget.currentUserId,
        location: newLocation,
      );

      _updateMap();
    });
  }

  void _listenToTripUpdates() {
    final tripService = Provider.of<TripService>(context, listen: false);

    _tripSubscription = tripService.streamTrip(widget.tripId).listen((trip) {
      if (trip != null) {
        _updateMap();
      }
    });

    _membersSubscription = tripService
        .streamMemberLocations(widget.tripId)
        .listen((memberLocations) {
      _updateMap();
    });
  }

  void _updateMap() {
    final tripService = Provider.of<TripService>(context, listen: false);
    final currentTrip = tripService.getTrip(widget.tripId);

    if (_currentLocation == null) return;

    setState(() {
      _markers.clear();
      _polylines.clear();

      // Add current user marker
      _markers.add(Marker(
        markerId: const MarkerId('currentUser'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: 'You'),
      ));

      // Add destination marker if available
      currentTrip.then((trip) {
        if (trip != null) {
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: trip.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: trip.destination),
          ));

          // Calculate distance
          _distance = Geolocator.distanceBetween(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
            trip.location.latitude,
            trip.location.longitude,
          ) / 1000; // Convert to km

          // Add polyline
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: [_currentLocation!, trip.latLng],
            color: Colors.blue,
            width: 4,
          ));
        }
      });

      // Center map on current location
      _mapController.animateCamera(
        CameraUpdate.newLatLng(_currentLocation!),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateMap,
          ),
        ],
      ),
      body: StreamBuilder<Trip?>(
        stream: Provider.of<TripService>(context).streamTrip(widget.tripId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trip = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? trip.latLng,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMap();
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Destination: ${trip.destination}',
                        style: const TextStyle(fontSize: 18)),
                    Text('Distance: ${_distance.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 16)),
                    Text('Members: ${trip.members.length}',
                        style: const TextStyle(fontSize: 16)),
                    Text('Last updated: ${DateFormat.jm().format(DateTime.now())}',
                        style: const TextStyle(fontSize: 14)),
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