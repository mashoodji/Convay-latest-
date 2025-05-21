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
    return Trip(
      id: id,
      adminId: data['adminId'] is String ? data['adminId'] : '',
      destination: data['destination'] is String ? data['destination'] : '',
      dateTime: (data['dateTime'] is Timestamp)
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      members: (data['members'] is List)
          ? List<String>.from(data['members'].whereType<String>())
          : [],
    );
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
