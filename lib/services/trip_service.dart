import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to generate trip ID from destination
  String generateTripId(String destination) {
    // Lowercase, remove spaces, take first 3 letters + _trip
    final code = destination.trim().toLowerCase().replaceAll(' ', '').substring(0, 3);
    return '${code}_trip';
  }

  // Create a new trip with custom trip ID
  Future<Trip?> createTrip({
    required String adminId,
    required String destination,
    required DateTime dateTime,
  }) async {
    try {
      final tripId = generateTripId(destination);

      // Use set() with custom doc ID to avoid duplicates you can add checks (optional)
      await _firestore.collection('trips').doc(tripId).set({
        'adminId': adminId,
        'destination': destination,
        'dateTime': dateTime,
        'members': [adminId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return Trip(
        id: tripId,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        members: [adminId],
      );
    } catch (e) {
      print('CreateTrip error: $e');
      return null;
    }
  }

  // Join an existing trip by custom trip ID
  Future<bool> joinTrip(String tripId, String userId) async {
    try {
      final docRef = _firestore.collection('trips').doc(tripId);
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
    return _firestore
        .collection('trips')
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
      DocumentSnapshot doc = await _firestore.collection('trips').doc(tripId).get();
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
