import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _tripsCollection => _firestore.collection('trips');
  CollectionReference get _locationsCollection => _firestore.collection('member_locations');

  String generateTripId(String destination) {
    final code = destination.trim().toLowerCase().replaceAll(' ', '');
    final prefix = code.length >= 3 ? code.substring(0, 3) : code;
    return '${prefix}_trip';
  }

  Future<Trip?> createTrip({
    required String adminId,
    required String destination,
    required DateTime dateTime,
    required LatLng location,
    String? tripId, required Map members,
  }) async {
    try {
      final generatedTripId = tripId ?? generateTripId(destination);
      final docRef = _tripsCollection.doc(generatedTripId);

      final tripData = {
        'adminId': adminId,
        'destination': destination,
        'dateTime': Timestamp.fromDate(dateTime),
        'location': GeoPoint(location.latitude, location.longitude),
        'members': [adminId],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(tripData);

      // Initialize admin location
      await updateMemberLocation(
        tripId: generatedTripId,
        userId: adminId,
        location: location,
      );

      return Trip(
        id: generatedTripId,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        location: GeoPoint(location.latitude, location.longitude),
        members: [adminId],
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error creating trip: $e');
      return null;
    }
  }

  Future<bool> joinTrip({
    required String tripId,
    required String userId,
    required LatLng location, required String name,
  }) async {
    try {
      final docRef = _tripsCollection.doc(tripId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) return false;

      await docRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });

      await updateMemberLocation(
        tripId: tripId,
        userId: userId,
        location: location,
      );

      return true;
    } catch (e) {
      print('JoinTrip Error: $e');
      return false;
    }
  }

  Future<void> updateMemberLocation({
    required String tripId,
    required String userId,
    required LatLng location,
  }) async {
    await _locationsCollection.doc('${tripId}_$userId').set({
      'tripId': tripId,
      'userId': userId,
      'location': GeoPoint(location.latitude, location.longitude),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Trip?> streamTrip(String tripId) {
    return _tripsCollection.doc(tripId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return Trip.fromMap(snapshot.id, snapshot.data() as Map<String, dynamic>);
    });
  }

  Stream<List<Trip>> getTrips() {
    return _tripsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<Trip?> getTrip(String tripId) async {
    try {
      final doc = await _tripsCollection.doc(tripId).get();
      if (doc.exists) {
        return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting trip: $e');
      return null;
    }
  }

  Stream<List<MemberLocation>> streamMemberLocations(String tripId) {
    return _locationsCollection
        .where('tripId', isEqualTo: tripId)
        .snapshots()
        .handleError((error) {
      print('Error streaming member locations: $error');
      return Stream.value([]); // Return empty list on error
    })
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        try {
          return MemberLocation.fromMap(doc.data() as Map<String, dynamic>);
        } catch (e) {
          print('Error parsing member location doc ${doc.id}: $e');
          return null;
        }
      }).where((loc) => loc != null).cast<MemberLocation>().toList();
    });
  }
}

class MemberLocation {
  final String tripId;
  final String userId;
  final GeoPoint location;
  final DateTime updatedAt;

  MemberLocation({
    required this.tripId,
    required this.userId,
    required this.location,
    required this.updatedAt,
  });

  factory MemberLocation.fromMap(Map<String, dynamic> data) {
    try {
      // Handle potential null values with proper fallbacks
      final tripId = data['tripId']?.toString() ?? '';
      final userId = data['userId']?.toString() ?? '';

      // Safely handle location data
      GeoPoint location;
      if (data['location'] is GeoPoint) {
        location = data['location'] as GeoPoint;
      } else if (data['location'] is Map) {
        final locData = data['location'] as Map;
        location = GeoPoint(
          (locData['latitude'] as num).toDouble(),
          (locData['longitude'] as num).toDouble(),
        );
      } else {
        throw Exception('Invalid location data');
      }

      // Handle timestamp conversion
      DateTime updatedAt;
      if (data['updatedAt'] is Timestamp) {
        updatedAt = (data['updatedAt'] as Timestamp).toDate();
      } else if (data['updatedAt'] is DateTime) {
        updatedAt = data['updatedAt'] as DateTime;
      } else {
        updatedAt = DateTime.now();
      }

      return MemberLocation(
        tripId: tripId,
        userId: userId,
        location: location,
        updatedAt: updatedAt,
      );
    } catch (e) {
      print('Error parsing MemberLocation: $e');
      rethrow;
    }
  }

  LatLng get latLng => LatLng(location.latitude, location.longitude);
}