import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../trip/trip_map_screen.dart';
import 'create_trip_screen.dart';
import 'join_trip_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convoy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final authService = Provider.of<AuthService>(context, listen: false);
              authService.signOut();
            },
          ),
        ],
      ),
      body: Consumer<TripService>(
        builder: (context, tripService, child) {
          return StreamBuilder<List<Trip>>(
            stream: tripService.getTrips(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final trips = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateTripScreen()),
                      );
                    },
                    child: const Text('Create New Trip'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const JoinTripScreen()),
                      );
                    },
                    child: const Text('Join Existing Trip'),
                  ),
                  const SizedBox(height: 20),
                  const Text('Active Trips:', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  ...trips.map((trip) {
                    final tripId = trip.id;
                    if (tripId.isEmpty) return const SizedBox(); // skip invalid trips

                    return ListTile(
                      title: Text('${trip.destination}'),
                      subtitle: Text('Trip ID: $tripId\n${trip.members.length} members'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripMapScreen(tripId: tripId),
                          ),
                        );
                      },
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}