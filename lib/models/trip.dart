import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String adminId;
  final String destination;
  final DateTime dateTime;
  final List<String> members;

  Trip({
    required this.id,
    required this.adminId,
    required this.destination,
    required this.dateTime,
    required this.members,
  });

  factory Trip.fromMap(String id, Map<String, dynamic> data) {
    try {
      // Debug log raw data
      print('Parsing Trip Data:');
      print('ID: $id');
      print('Raw data: $data');

      // Parse with fallbacks
      final adminId = data['adminId']?.toString() ?? '';
      final destination = data['destination']?.toString() ?? '';

      DateTime dateTime;
      if (data['dateTime'] is Timestamp) {
        dateTime = (data['dateTime'] as Timestamp).toDate();
      } else if (data['dateTime'] is DateTime) {
        dateTime = data['dateTime'] as DateTime;
      } else {
        print('Warning: Invalid dateTime format, using now()');
        dateTime = DateTime.now();
      }

      // Parse members list safely
      List<String> members = [];
      if (data['members'] is List) {
        members = (data['members'] as List)
            .map((e) => e?.toString())
            .where((e) => e != null)
            .cast<String>()
            .toList();
      }

      print('Successfully parsed trip: ${{
        'id': id,
        'adminId': adminId,
        'destination': destination,
        'dateTime': dateTime,
        'members': members
      }}');

      return Trip(
        id: id,
        adminId: adminId,
        destination: destination,
        dateTime: dateTime,
        members: members,
      );
    } catch (e) {
      print('Failed to parse Trip: $e');
      rethrow; // Or return a default trip if preferred
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'destination': destination,
      'dateTime': Timestamp.fromDate(dateTime),
      'members': members,
    };
  }
}
