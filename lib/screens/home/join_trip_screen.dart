import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../trip/trip_map_screen.dart';

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _tripIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinTrip() async {
    if (_tripIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a trip ID')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final tripService = Provider.of<TripService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final success = await tripService.joinTrip(
      _tripIdController.text.trim(),
      authService.currentUser!.uid,
    );

    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripMapScreen(tripId: _tripIdController.text),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip not found or join failed. Check Trip ID and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Existing Trip')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _tripIdController,
              decoration: const InputDecoration(
                labelText: 'Trip ID',
                hintText: 'Enter the trip ID provided by the convoy admin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _joinTrip,
              child: const Text('Join Trip'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tripIdController.dispose();
    super.dispose();
  }
}