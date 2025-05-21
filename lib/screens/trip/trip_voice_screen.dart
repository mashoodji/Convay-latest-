import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/voice_service.dart';

class TripVoiceScreen extends StatefulWidget {
  final String tripId;

  const TripVoiceScreen({super.key, required this.tripId});

  @override
  State<TripVoiceScreen> createState() => _TripVoiceScreenState();
}

class _TripVoiceScreenState extends State<TripVoiceScreen> {
  bool _isMuted = false;
  bool _isSpeaking = false;

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Convoy Voice Chat')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.record_voice_over, size: 100),
            const SizedBox(height: 20),
            Text(
              _isMuted ? 'Microphone Muted' : 'Microphone Active',
              style: TextStyle(
                fontSize: 20,
                color: _isMuted ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  color: _isMuted ? Colors.red : Colors.green,
                  iconSize: 50,
                  onPressed: () {
                    setState(() => _isMuted = !_isMuted);
                    voiceService.toggleMute(widget.tripId, _isMuted);
                  },
                ),
                const SizedBox(width: 30),
                FloatingActionButton(
                  backgroundColor: _isSpeaking ? Colors.red : Colors.blue,
                  onPressed: () {
                    setState(() => _isSpeaking = !_isSpeaking);
                    voiceService.updateSpeakingStatus(
                      widget.tripId,
                      _isSpeaking,
                    );
                  },
                  child: Icon(
                    _isSpeaking ? Icons.stop : Icons.keyboard_voice,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Hold the button to speak\nRelease to stop',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}