import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

class LocationService {
  final loc.Location _location = loc.Location();

  // Check if location services are enabled
  Future<bool> _checkLocationService() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    return true;
  }

  // Check location permissions
  Future<bool> _checkLocationPermission() async {
    loc.PermissionStatus permission = await _location.hasPermission();
    if (permission == loc.PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != loc.PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  // Get current device location
  Future<LatLng?> getCurrentLocation() async {
    try {
      final serviceEnabled = await _checkLocationService();
      if (!serviceEnabled) return null;

      final permissionGranted = await _checkLocationPermission();
      if (!permissionGranted) return null;

      final locationData = await _location.getLocation();
      return LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Convert address to coordinates (geocoding)
  Future<LatLng?> getLocationFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  // Convert coordinates to address (reverse geocoding)
  Future<String?> getAddressFromLocation(LatLng position) async {
    try {
      final addresses = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (addresses.isNotEmpty) {
        final place = addresses.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      return null;
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }
}