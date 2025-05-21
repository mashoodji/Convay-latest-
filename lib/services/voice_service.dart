import 'package:firebase_database/firebase_database.dart';

class VoiceService {
  final DatabaseReference _rtcRef = FirebaseDatabase.instance.ref('voice_chat');

  void updateSpeakingStatus(String tripId, bool isSpeaking) {
    _rtcRef.child(tripId).child('speaking').set(isSpeaking);
  }

  void toggleMute(String tripId, bool isMuted) {
    _rtcRef.child(tripId).child('muted').set(isMuted);
  }

  Stream<Map<String, dynamic>> getVoiceStatus(String tripId) {
    return _rtcRef.child(tripId).onValue.map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return {
        'speaking': data['speaking'] ?? false,
        'muted': data['muted'] ?? false,
      };
    });
  }
}