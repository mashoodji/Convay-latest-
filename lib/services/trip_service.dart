import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new trip
  Future<Trip?> createTrip({
    required String adminId,
    required String destination,
    required DateTime dateTime,
  }) async {
    try {
      DocumentReference docRef = await _firestore.collection('trips').add({
        'adminId': adminId,
        'destination': destination,
        'dateTime': dateTime,
        'members': [adminId],
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Trip(
        id: docRef.id,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        members: [adminId],
      );
    } catch (e) {
      return null;
    }
  }

  // Join an existing trip
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


  // Get stream of trips
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

  // Get single trip
  Future<Trip?> getTrip(String tripId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('trips').doc(tripId).get();
      if (doc.exists) {
        return Trip.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}