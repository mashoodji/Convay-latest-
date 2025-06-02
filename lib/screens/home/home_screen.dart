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
      backgroundColor: Colors.white, // Set background to white
      appBar: AppBar(
        title: const Text(
          'Convoy',
          style: TextStyle(
            color: Color(0xFF1A237E), // Dark blue for app bar title
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white, // White app bar background
        elevation: 0, // No shadow for a clean look
        centerTitle: true, // Center the title
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1A237E)), // Dark blue logout icon
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
                return const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
              }

              final trips = snapshot.data ?? [];

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/c44674bf-abc7-4fe5-9a6f-b28dabbc6d3e.png', // Add a relevant image for the home screen
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          label: const Text(
                            'Create New Trip',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white, // Larger button
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // Rounded corners
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const JoinTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.group_add_outlined, color: Colors.black), // Dark blue icon
                          label: const Text(
                            'Join Existing Trip',
                            style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // White background
                            foregroundColor: const Color(0xFF1A237E), // Dark blue text color
                            side: const BorderSide(color: Color(0xFF1A237E), width: 2), // Dark blue border
                            minimumSize: const Size.fromHeight(50), // Larger button
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25), // Rounded corners
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Active Trips:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black // Dark blue heading
                          ),
                        ),
                        const Divider(color: Color(0xFF1A237E), thickness: 1), // Blue divider
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Expanded(
                    child: trips.isEmpty
                        ? const Center(
                      child: Text(
                        'No active trips. Create or join one!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : ListView.builder(
                      itemCount: trips.length,
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        final tripId = trip.id;
                        if (tripId.isEmpty) return const SizedBox();

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15), // Rounded card corners
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            leading: const Icon(Icons.map, color: Colors.black, size: 30), // Map icon
                            title: Text(
                              '${trip.destination}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trip ID: $tripId',
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                Text(
                                  '${trip.members.length} members',
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF1A237E)), // Forward arrow
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TripMapScreen(tripId: tripId, currentUserId: '',),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}