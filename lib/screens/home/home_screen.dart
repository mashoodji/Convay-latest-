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
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Convoy',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1A237E)),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Consumer<TripService>(
        builder: (context, tripService, child) {
          return StreamBuilder<List<Trip>>(
            stream: tripService.getTrips(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1A237E)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
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
                          'assets/images/c44674bf-abc7-4fe5-9a6f-b28dabbc6d3e.png',
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 30),
                        _buildActionButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateTripScreen(),
                            ),
                          ),
                          icon: Icons.add_circle_outline,
                          label: 'Create New Trip',
                          backgroundColor: Colors.black,
                          textColor: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const JoinTripScreen(),
                            ),
                          ),
                          icon: Icons.group_add_outlined,
                          label: 'Join Existing Trip',
                          backgroundColor: Colors.white,
                          textColor: Colors.black,
                          borderColor: const Color(0xFF1A237E),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Active Trips:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Divider(color: Color(0xFF1A237E), thickness: 1),
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
                        return _buildTripCard(context, trip, currentUserId);
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color borderColor = Colors.transparent,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: textColor),
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        side: BorderSide(color: borderColor, width: 2),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip, String currentUserId) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(Icons.map, color: Colors.black, size: 30),
        title: Text(
          trip.destination,
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
              'Trip ID: ${trip.id}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              '${trip.members.length} members',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF1A237E)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripMapScreen(
                tripId: trip.id,
                currentUserId: currentUserId,
              ),
            ),
          );
        },
      ),
    );
  }
}