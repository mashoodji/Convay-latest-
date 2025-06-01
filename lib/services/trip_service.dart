import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _tripsCollection => _firestore.collection('trips');

  // Helper to generate trip ID from first 3 letters of destination
  String generateTripId(String destination) {
    final code = destination.trim().toLowerCase().replaceAll(' ', '');
    final prefix = code.length >= 3 ? code.substring(0, 3) : code;
    return '${prefix}_trip';
  }

  Future<Trip?> createTrip({
    required String adminId,
    required String destination,
    required DateTime dateTime,
    LatLng? location,
    String? tripId,
  }) async {
    try {
      final generatedTripId = tripId ?? generateTripId(destination);
      final docRef = _tripsCollection.doc(generatedTripId);

      final tripData = {
        'adminId': adminId,
        'destination': destination,
        'dateTime': Timestamp.fromDate(dateTime),
        'members': [adminId],
        if (location != null) 'location': GeoPoint(location.latitude, location.longitude),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(tripData);

      return Trip(
        id: generatedTripId,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        members: [adminId],
        location: location != null ? GeoPoint(location.latitude, location.longitude) : null,
      );
    } catch (e) {
      print('Error creating trip: $e');
      return null;
    }
  }

  Future<bool> joinTrip(String tripId, String userId) async {
    try {
      final docRef = _tripsCollection.doc(tripId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        print('Trip not found: $tripId');
        return false;
      }

      await docRef.update({
        'members': FieldValue.arrayUnion([userId]),
      });

      return true;
    } catch (e) {
      print('JoinTrip Error: $e');
      return false;
    }
  }

  Stream<List<Trip>> getTrips() {
    return _tripsCollection
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<Trip?> getTrip(String tripId) async {
    try {
      DocumentSnapshot doc = await _tripsCollection.doc(tripId).get();
      if (doc.exists) {
        return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('GetTrip Error: $e');
      return null;
    }
  }
}
