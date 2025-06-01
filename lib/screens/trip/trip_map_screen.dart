import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart'; // Add this import
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
  GoogleMapController? _mapController;  // <-- nullable now
  late Timer _timer;
  List<LatLng> _memberPositions = [];
  Set<Marker> _markers = {};
  Trip? _trip;

  @override
  void initState() {
    super.initState();
    _loadTrip();
    _timer = Timer.periodic(const Duration(seconds: 3), _updatePositions);
  }

  Future<void> _loadTrip() async {
    final tripService = Provider.of<TripService>(context, listen: false);
    final tripData = await tripService.getTrip(widget.tripId);

    if (mounted) {
      setState(() {
        _trip = tripData;
        if (_trip?.latLng != null) {
          _memberPositions = [_trip!.latLng!];
          _updateMarkers();

          // Safely animate camera only if controller is ready
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_trip!.latLng!, 14),
            );
          }
        }
      });
    }
  }

  void _updatePositions(Timer timer) {
    if (!mounted || _trip == null) return;

    setState(() {
      _memberPositions = _memberPositions.map((pos) {
        return LatLng(pos.latitude + 0.0001, pos.longitude + 0.0001);
      }).toList();
      _updateMarkers();
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
        infoWindow: InfoWindow(title: 'Member ${idx + 1}'),
      );
    }).toSet();

    if (_trip?.latLng != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _trip!.latLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: _trip!.destination),
      ));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _mapController?.dispose();  // <-- safely dispose if not null
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
                target: _trip?.latLng ?? const LatLng(0, 0),
                zoom: _trip?.latLng != null ? 12 : 1,
              ),
              onMapCreated: (controller) {
                _mapController = controller;

                // Animate camera to trip location if loaded
                if (_trip?.latLng != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_trip!.latLng!, 14),
                  );
                }
              },
              markers: _markers,
              myLocationEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination: ${_trip!.destination}',
                    style: const TextStyle(fontSize: 18)),
                Text('Date: ${DateFormat.yMMMd().format(_trip!.dateTime)}',
                    style: const TextStyle(fontSize: 16)),
                Text('Time: ${DateFormat.jm().format(_trip!.dateTime)}',
                    style: const TextStyle(fontSize: 16)),
                Text('Members: ${_trip!.members.length}',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
