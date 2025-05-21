import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../trip/trip_map_screen.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _destinationController = TextEditingController();
  DateTime _tripDate = DateTime.now();
  TimeOfDay _tripTime = TimeOfDay.now();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _tripDate) {
      setState(() => _tripDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _tripTime,
    );
    if (picked != null && picked != _tripTime) {
      setState(() => _tripTime = picked);
    }
  }

  Future<void> _createTrip() async {
    if (_destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final tripService = Provider.of<TripService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final dateTime = DateTime(
      _tripDate.year,
      _tripDate.month,
      _tripDate.day,
      _tripTime.hour,
      _tripTime.minute,
    );

    final trip = await tripService.createTrip(
      adminId: authService.currentUser!.uid,
      destination: _destinationController.text,
      dateTime: dateTime,
    );

    setState(() => _isLoading = false);

    if (trip != null) {
      // Show Trip ID in a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trip Created'),
          content: Text('Trip ID: ${trip.id}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Navigate to the trip map screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripMapScreen(tripId: trip.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create trip')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Trip')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Where are you going?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(DateFormat.yMMMd().format(_tripDate)),
                    subtitle: const Text('Trip date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(_tripTime.format(context)),
                    subtitle: const Text('Trip time'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(context),
                  ),
                ),
              ],
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

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }
}