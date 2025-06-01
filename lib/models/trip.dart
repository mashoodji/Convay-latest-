import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Trip {
  final String id;
  final String adminId;
  final String destination;
  final DateTime dateTime;
  final List<String> members;
  final GeoPoint? location;

  Trip({
    required this.id,
    required this.adminId,
    required this.destination,
    required this.dateTime,
    required this.members,
    this.location,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    try {
      final adminId = data['adminId']?.toString() ?? '';
      final destination = data['destination']?.toString() ?? '';

      DateTime dateTime;
      if (data['dateTime'] is Timestamp) {
        dateTime = (data['dateTime'] as Timestamp).toDate();
      } else if (data['dateTime'] is DateTime) {
        dateTime = data['dateTime'] as DateTime;
      } else {
        dateTime = DateTime.now();
      }

      List<String> members = [];
      if (data['members'] is List) {
        members = (data['members'] as List)
            .map((e) => e?.toString())
            .where((e) => e != null)
            .cast<String>()
            .toList();
      }

      GeoPoint? location;
      if (data['location'] is GeoPoint) {
        location = data['location'] as GeoPoint;
      }

      return Trip(
        id: id,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        members: members,
        location: location,
      );
    } catch (e) {
      print('Failed to parse Trip: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'destination': destination,
      'dateTime': Timestamp.fromDate(dateTime),
      'members': members,
      'location': location,
    };
  }

  LatLng? get latLng {
    if (location == null) return null;
    return LatLng(location!.latitude, location!.longitude);
  }
}