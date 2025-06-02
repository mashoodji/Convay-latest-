import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../trip/trip_map_screen.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _destinationController = TextEditingController();
  DateTime _tripDate = DateTime.now();
  TimeOfDay _tripTime = TimeOfDay.now();
  bool _isLoading = false;
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  String _generateShortForm(String destination) {
    List<String> words = destination.split(' ');
    String shortForm = words.map((word) => word[0].toUpperCase()).join();
    return shortForm;
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        );
      });

      // Center the map on current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: ${e.toString()}')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _tripDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _tripTime,
    );
    if (picked != null) setState(() => _tripTime = picked);
  }

  Future<void> _searchLocation() async {
    if (_destinationController.text.trim().isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(_destinationController.text.trim());
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);

        setState(() {
          _selectedLocation = latLng;
          _markers.removeWhere((m) => m.markerId.value == 'destination');
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: latLng,
              infoWindow: InfoWindow(title: _destinationController.text.trim()),
            ),
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 14),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not found: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleMapTap(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String address = [
          // if (place.name != null && place.name!.isNotEmpty) place.name,
          // if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) place.subThoroughfare,
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) place.thoroughfare,
          if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
          if (place.locality != null && place.locality!.isNotEmpty) place.locality,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) place.subAdministrativeArea,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
          if (place.postalCode != null && place.postalCode!.isNotEmpty) place.postalCode,
          if (place.country != null && place.country!.isNotEmpty) place.country,
        ].join(', ');

        setState(() {
          _selectedLocation = latLng;
          _destinationController.text = address;
          _markers.removeWhere((m) => m.markerId.value == 'destination');
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: latLng,
              infoWindow: InfoWindow(title: address),
            ),
          );
        });
      } else {
        throw Exception("No placemarks found");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get address: ${e.toString()}')),
      );
    }
  }

  Future<void> _createTrip() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty || _selectedLocation == null) {
      _showSnackBar('Please select a destination');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tripId = _generateTripId(destination);
      final dateTime = DateTime(
        _tripDate.year,
        _tripDate.month,
        _tripDate.day,
        _tripTime.hour,
        _tripTime.minute,
      );

      final tripService = Provider.of<TripService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final trip = await tripService.createTrip(
        tripId: tripId,
        adminId: authService.currentUser!.uid,
        destination: destination,
        dateTime: dateTime,
        location: _selectedLocation!, members: {},
      );

      setState(() => _isLoading = false);

      if (trip == null) {
        _showSnackBar('Failed to create trip');
        return;
      }

      await _showTripCreatedDialog(trip.id);
      _navigateToTripMap(trip.id, authService.currentUser!.uid);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error creating trip: $e');
    }
  }

  String _generateTripId(String destination) {
    // Remove non-alphanumeric characters and convert to lowercase
    final sanitized = destination.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

    // Take the first 3 letters, or the whole string if less than 3 letters
    final prefix = sanitized.length >= 3 ? sanitized.substring(0, 3) : sanitized;

    return '${prefix}_trip';
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showTripCreatedDialog(String tripId) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trip Created'),
        content: Text('Trip ID: $tripId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToTripMap(String tripId, String currentUserId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TripMapScreen(
          tripId: tripId,
          currentUserId: currentUserId,
        ),
      ),
    );
  }


  @override
  void dispose() {
    _destinationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          'Create Trip',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/images/login.png',
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 25),

            const Text(
              'Destination',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  hintText: 'e.g. New York City',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchLocation,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
            const SizedBox(height: 20),

            // Map Preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(0, 0),
                    zoom: _currentLocation != null ? 14 : 1,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (_currentLocation != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 14),
                      );
                    }
                  },
                  markers: _markers,
                  onTap: _handleMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,            // Show + / - buttons
                  zoomGesturesEnabled: true,           // Enable pinch-to-zoom
                  scrollGesturesEnabled: true,         // Enable map dragging
                  rotateGesturesEnabled: true,         // Optional: allow rotation
                  tiltGesturesEnabled: true,           // Optional: allow tilt
                  minMaxZoomPreference: const MinMaxZoomPreference(5, 18),

                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _DateTimePickerCard(
                    label: 'Date',
                    value: DateFormat.yMMMd().format(_tripDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _selectDate(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateTimePickerCard(
                    label: 'Time',
                    value: _tripTime.format(context),
                    icon: Icons.access_time,
                    onTap: () => _selectTime(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _createTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Create Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Rest of your existing UI elements...
            Center(
              child: Text(
                'Adventure awaits — plan it right!',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.black : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 30),
            Divider(
              thickness: 1,
              color: Colors.grey.shade300,
              indent: 60,
              endIndent: 60,
            ),
            const SizedBox(height: 25),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.airplanemode_active, size: 22, color: Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    'Let your journey begin!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            Center(
              child: Column(
                children: [
                  Text(
                    'Need help?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact support or visit the FAQ sections',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _DateTimePickerCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimePickerCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}