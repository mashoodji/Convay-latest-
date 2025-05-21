import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/trip_service.dart';
import '../../services/auth_service.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final TextEditingController _destinationController = TextEditingController();
  DateTime? _selectedDateTime;

  bool _isLoading = false;

  Future<void> _createTrip() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tripService = Provider.of<TripService>(context, listen: false);
    final user = authService.currentUser;
    final destination = _destinationController.text.trim();

    if (user == null || destination.isEmpty || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final trip = await tripService.createTrip(
        adminId: user.uid,
        destination: destination,
        dateTime: _selectedDateTime!,
      );

      if (trip != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip created with ID: ${trip.id}')),
        );
        Navigator.pop(context);
      } else {
        throw Exception("Failed to create trip.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Trip'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destination'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _pickDateTime,
              child: Text(_selectedDateTime == null
                  ? 'Pick Date & Time'
                  : 'Selected: ${_selectedDateTime.toString()}'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _createTrip,
              child: const Text('Create Trip'),
            ),
          ],
        ),
      ),
    );
  }
}
