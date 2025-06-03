import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../services/gomaps_service.dart';
import '../../services/trip_service.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;
  final String currentUserId;

  const TripMapScreen({
    Key? key,
    required this.tripId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _currentLocation;
  LatLng? _destination;
  double _distanceKm = 0.0;
  Duration? _estimatedDuration;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<Trip?>? _tripSubscription;
  StreamSubscription<List<MemberLocation>>? _membersSubscription;

  final RouteService _routeService = RouteService('AlzaSyVJMVyUnx7Jb_mOU4WgFDE6jcRKa3H1EYF');
  final Map<String, Color> _memberColors = {};
  final Map<String, Duration?> _memberDurations = {};
  final Map<String, LatLng> _memberLocations = {};

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

  String _shortMemberId(String userId) {
    if (userId.isEmpty) return '?';
    return userId.length > 6 ? userId.substring(0, 6) : userId;
  }

  Color _getMemberColor(String userId) {
    if (!_memberColors.containsKey(userId)) {
      final idx = _memberColors.length % Colors.primaries.length;
      _memberColors[userId] = Colors.primaries[idx];
    }
    return _memberColors[userId]!;
  }

  void _setupLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position pos) async {
      final newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = newLoc);

      try {
        await Provider.of<TripService>(context, listen: false)
            .updateMemberLocation(
          tripId: widget.tripId,
          userId: widget.currentUserId,
          location: newLoc,
        );

        if (_destination != null) {
          _updateRoute(newLoc, _destination!);
        }
      } catch (e) {
        print('Error updating location: $e');
      }
    }, onError: (e) {
      print('Location stream error: $e');
    });
  }

  void _listenToTripUpdates() {
    final tripService = Provider.of<TripService>(context, listen: false);

    _tripSubscription = tripService.streamTrip(widget.tripId).listen((trip) {
      if (trip != null) {
        setState(() => _destination = trip.latLng);
        if (_currentLocation != null) {
          _updateRoute(_currentLocation!, trip.latLng);
        }
      }
    }, onError: (e) {
      print('Trip stream error: $e');
    });

    _membersSubscription = tripService.streamMemberLocations(widget.tripId).listen((members) {
      _updateMemberMarkers(members);
      if (_destination != null) {
        _updateMemberRoutes(_destination!, members);
      }
    }, onError: (e) {
      print('Member locations stream error: $e');
    });
  }

  Future<void> _updateRoute(LatLng origin, LatLng destination) async {
    try {
      // Clear existing route
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'your_route');
      });

      // Get new directions
      final directions = await _routeService.getRouteDirections(
        origin: origin,
        destination: destination,
      );

      if (directions != null) {
        final points = _routeService.extractPolyline(directions);
        final dd = _routeService.extractDistanceAndDuration(directions);

        setState(() {
          // Add new route
          if (points.isNotEmpty) {
            _polylines.add(Polyline(
              polylineId: const PolylineId('your_route'),
              points: points,
              color: Colors.blue,
              width: 5,
            ));
          }

          // Update distance and duration
          if (dd['distance_m'] != null) {
            _distanceKm = (dd['distance_m'] as int) / 1000;
          }
          if (dd['duration_s'] != null) {
            _estimatedDuration = Duration(seconds: dd['duration_s'] as int);
          }

          // Update current location marker
          _markers.removeWhere((m) => m.markerId.value == 'currentUser');
          _markers.add(Marker(
            markerId: const MarkerId('currentUser'),
            position: origin,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'You'),
          ));

          // Ensure destination marker exists
          _markers.removeWhere((m) => m.markerId.value == 'destination');
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: destination,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destination'),
          ));
        });

        _fitMapToBounds(destination);
      }
    } catch (e) {
      print('Error updating route: $e');
    }
  }

  void _updateMemberMarkers(List<MemberLocation> members) {
    setState(() {
      // Clear all member markers except current user and destination
      _markers.removeWhere((m) =>
      m.markerId.value != 'currentUser' &&
          m.markerId.value != 'destination');

      // Store member locations and add their markers
      for (final member in members) {
        _memberLocations[member.userId] = member.latLng;
        if (member.userId != widget.currentUserId) {
          _markers.add(Marker(
            markerId: MarkerId(member.userId),
            position: member.latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Member ${_shortMemberId(member.userId)}'),
          ));
        }
      }
    });
  }

  Future<void> _updateMemberRoutes(LatLng destination, List<MemberLocation> members) async {
    try {
      setState(() {
        // Clear all member routes
        _polylines.removeWhere((p) => p.polylineId.value.startsWith('route_'));
      });

      for (final member in members) {
        if (member.userId == widget.currentUserId) continue;

        final directions = await _routeService.getRouteDirections(
          origin: member.latLng,
          destination: destination,
        );

        if (directions != null) {
          final points = _routeService.extractPolyline(directions);
          final dd = _routeService.extractDistanceAndDuration(directions);

          setState(() {
            if (points.isNotEmpty) {
              _polylines.add(Polyline(
                polylineId: PolylineId('route_${member.userId}'),
                points: points,
                color: _getMemberColor(member.userId),
                width: 4,
              ));
            }

            if (dd['duration_s'] != null) {
              _memberDurations[member.userId] = Duration(seconds: dd['duration_s'] as int);
            }
          });
        }
      }
    } catch (e) {
      print('Error updating member routes: $e');
    }
  }

  void _fitMapToBounds(LatLng destination) {
    if (_currentLocation == null || _mapController == null) return;

    try {
      // Include all markers in bounds calculation
      final points = [_currentLocation!, destination];
      points.addAll(_memberLocations.values);

      final southLat = points.map((p) => p.latitude).reduce(min) - 0.01;
      final westLng = points.map((p) => p.longitude).reduce(min) - 0.01;
      final northLat = points.map((p) => p.latitude).reduce(max) + 0.01;
      final eastLng = points.map((p) => p.longitude).reduce(max) + 0.01;

      final bounds = LatLngBounds(
        southwest: LatLng(southLat, westLng),
        northeast: LatLng(northLat, eastLng),
      );

      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('Error fitting bounds: $e');
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    }
  }

  String _formatDuration(Duration? d) {
    if (d == null) return 'Calculating…';
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
    }
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_currentLocation != null && _destination != null) {
                _updateRoute(_currentLocation!, _destination!);
              }
            },
          )
        ],
      ),
      body: StreamBuilder<Trip?>(
        stream: Provider.of<TripService>(context).streamTrip(widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
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
                    if (_currentLocation != null && _destination == null) {
                      _updateRoute(_currentLocation!, trip.latLng);
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Destination: ${trip.destination}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.linear_scale, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.timer, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(_estimatedDuration),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MemberLocation>>(
                      stream: Provider.of<TripService>(context)
                          .streamMemberLocations(widget.tripId),
                      builder: (context, memberSnap) {
                        if (memberSnap.hasError) {
                          return Text('Error: ${memberSnap.error}');
                        }
                        if (!memberSnap.hasData) {
                          return const Text('Loading members…');
                        }

                        final otherMembers = memberSnap.data!
                            .where((m) => m.userId != widget.currentUserId)
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Members: ${otherMembers.length + 1}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            // Current user
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('You', style: TextStyle(fontSize: 14)),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(_estimatedDuration),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Other members
                            ...otherMembers.map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _getMemberColor(m.userId),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Member ${_shortMemberId(m.userId)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDuration(_memberDurations[m.userId]),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateFormat.jm().format(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
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