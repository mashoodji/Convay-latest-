import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Trip {
  final String id;
  final String adminId;
  final String destination;
  final DateTime dateTime;
  final GeoPoint location;
  final List<String> members;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.adminId,
    required this.destination,
    required this.dateTime,
    required this.location,
    required this.members,
    required this.createdAt,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    return Trip(
      id: id,
      adminId: data['adminId'] as String,
      destination: data['destination'] as String,
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      location: data['location'] as GeoPoint,
      members: List<String>.from(data['members'] as List),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'destination': destination,
      'dateTime': Timestamp.fromDate(dateTime),
      'location': location,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  LatLng get latLng => LatLng(location.latitude, location.longitude);
}