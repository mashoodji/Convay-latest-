// lib/screens/trip_map_screen.dart
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
  double _distanceKm = 0.0;
  Duration? _estimatedDuration;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<Trip?>? _tripSubscription;
  StreamSubscription<List<MemberLocation>>? _membersSubscription;

  // Initialize with your GoMaps API key
  final RouteService _routeService =
  RouteService('AlzaSyVJMVyUnx7Jb_mOU4WgFDE6jcRKa3H1EYF');

  // For assigning each member a unique color
  final Map<String, Color> _memberColors = {};
  final Map<String, Duration?> _memberDurations = {};

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

  /// Returns a short display version of a userId (first 6 chars) or “?” if missing.
  String _shortMemberId(String userId) {
    if (userId.isEmpty) return '?';
    return userId.length > 6 ? userId.substring(0, 6) : userId;
  }

  /// Assigns each member a distinct color (cycling through Flutter’s primaries).
  Color _getMemberColor(String userId) {
    if (!_memberColors.containsKey(userId)) {
      final idx = _memberColors.length % Colors.primaries.length;
      _memberColors[userId] = Colors.primaries[idx];
    }
    return _memberColors[userId]!;
  }

  /// Start listening to the device’s real-time position.
  void _setupLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position pos) async {
      final newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = newLoc);

      // Update your location in Firestore (or wherever TripService stores it)
      try {
        await Provider.of<TripService>(context, listen: false)
            .updateMemberLocation(
          tripId: widget.tripId,
          userId: widget.currentUserId,
          location: newLoc,
        );
        _updateMap(); // redraw routes & markers
      } catch (e) {
        print('[TripMapScreen] Error updating member location: $e');
      }
    }, onError: (e) {
      print('[TripMapScreen] Location stream error: $e');
    });
  }

  /// Listen to changes in Trip data and member locations.
  void _listenToTripUpdates() {
    final tripService = Provider.of<TripService>(context, listen: false);

    // Whenever the Trip info itself changes (e.g. destination or status),
    // re‐draw the map.
    _tripSubscription = tripService.streamTrip(widget.tripId).listen((trip) {
      if (trip != null) {
        _updateMap();
      }
    }, onError: (e) {
      print('[TripMapScreen] Trip stream error: $e');
    });

    // Whenever the members’ positions change, recalculate their routes.
    _membersSubscription =
        tripService.streamMemberLocations(widget.tripId).listen((members) {
          tripService.getTrip(widget.tripId).then((trip) {
            if (trip != null) {
              _updateMemberRoutes(trip.latLng, members);
            }
          }).catchError((e) {
            print('[TripMapScreen] Error fetching trip for member routes: $e');
          });
        }, onError: (e) {
          print('[TripMapScreen] Member locations stream error: $e');
        });
  }

  /// Redraw the “You → Destination” route (distance + duration + polyline).
  Future<void> _updateMap() async {
    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final currentTrip = await tripService.getTrip(widget.tripId);
      if (_currentLocation == null || currentTrip == null) return;

      setState(() {
        _markers.clear();
        _polylines.clear();

        // 1) “You” marker
        _markers.add(Marker(
          markerId: const MarkerId('currentUser'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You'),
        ));

        // 2) Destination marker
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: currentTrip.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: currentTrip.destination),
        ));

        // 3) Straight‐line distance (for quick display)
        _distanceKm = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          currentTrip.latLng.latitude,
          currentTrip.latLng.longitude,
        ) /
            1000;
      });

      // 4) Fetch and draw detailed route via GoMaps:
      final directionsJson = await _routeService.getRouteDirections(
        origin: _currentLocation!,
        destination: currentTrip.latLng,
      );

      if (directionsJson != null) {
        // a) Extract polyline points
        final polyPoints = _routeService.extractPolyline(directionsJson);
        if (polyPoints.isNotEmpty) {
          setState(() {
            _polylines.add(Polyline(
              polylineId: const PolylineId('your_route'),
              points: polyPoints,
              color: Colors.blue,
              width: 5,
            ));
          });
        }

        // b) Extract distance & duration from JSON
        final dd = _routeService.extractDistanceAndDuration(directionsJson);
        final distMeters = dd['distance_m'] as int?;
        final durSeconds = dd['duration_s'] as int?;
        setState(() {
          if (distMeters != null) {
            _distanceKm = distMeters / 1000;
          }
          if (durSeconds != null) {
            _estimatedDuration = Duration(seconds: durSeconds);
          }
        });
      }

      // 5) Center the camera to include both “You” and destination
      _fitMapToBounds(currentTrip.latLng);
    } catch (e) {
      print('[TripMapScreen] Error in _updateMap: $e');
    }
  }

  /// Draw or update routes for each member → Destination.
  Future<void> _updateMemberRoutes(
      LatLng destination, List<MemberLocation> members) async {
    try {
      for (final member in members) {
        if (member.userId == widget.currentUserId) continue;

        final directionsJson = await _routeService.getRouteDirections(
          origin: member.latLng,
          destination: destination,
        );

        if (directionsJson != null) {
          // a) Polyline for member
          final memberPoints = _routeService.extractPolyline(directionsJson);
          if (memberPoints.isNotEmpty) {
            setState(() {
              _polylines.add(Polyline(
                polylineId: PolylineId('route_${member.userId}'),
                points: memberPoints,
                color: _getMemberColor(member.userId),
                width: 4,
              ));
            });
          }

          // b) Member’s ETA
          final dd = _routeService.extractDistanceAndDuration(directionsJson);
          final durSeconds = dd['duration_s'] as int?;
          _memberDurations[member.userId] =
          durSeconds != null ? Duration(seconds: durSeconds) : null;

          // c) Member marker
          setState(() {
            _markers.add(Marker(
              markerId: MarkerId(member.userId),
              position: member.latLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                  title: 'Member ${_shortMemberId(member.userId)}'),
            ));
          });
        }
      }
    } catch (e) {
      print('[TripMapScreen] Error updating member routes: $e');
    }
  }

  /// Adjust camera so that both “You” and destination (and any member polylines)
  /// fit within view. Adds a small padding of 0.01 degrees lat/lng.
  void _fitMapToBounds(LatLng destination) {
    if (_currentLocation == null) return;

    try {
      final southLat =
          min(_currentLocation!.latitude, destination.latitude) - 0.01;
      final westLng =
          min(_currentLocation!.longitude, destination.longitude) - 0.01;
      final northLat =
          max(_currentLocation!.latitude, destination.latitude) + 0.01;
      final eastLng =
          max(_currentLocation!.longitude, destination.longitude) + 0.01;

      final bounds = LatLngBounds(
        southwest: LatLng(southLat, westLng),
        northeast: LatLng(northLat, eastLng),
      );

      _mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('[TripMapScreen] Error fitting bounds: $e');
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    }
  }

  /// Format a Duration into “Xh Ymin” or “Z min”
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
            onPressed: _updateMap,
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
                    _updateMap();
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
              Container(
                width: double.infinity,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Destination title
                    Text(
                      'Destination: ${trip.destination}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Distance & Duration row
                    Row(
                      children: [
                        const Icon(Icons.linear_scale,
                            size: 16, color: Colors.blue),
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
                    const SizedBox(height: 12),

                    // Members list + ETA
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
                        final members = memberSnap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Members: ${members.length + 1}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            // For each member, show a color dot + short ID + ETA
                            ...members.map((m) {
                              return Padding(
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
                                      _formatDuration(
                                          _memberDurations[m.userId]),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Last-updated timestamp
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
