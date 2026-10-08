import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ubwinza_users/features/delivery/presentation/deliveries_tracking_view.dart';
import '../../../global/global_instances.dart';
import '../../../global/global_vars.dart'; // Add for sharedPreferences

class DeliveriesListScreen extends StatefulWidget {
  const DeliveriesListScreen({super.key});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  String? userId;
  bool _isLoading = true;

  // Track canceled delivery IDs to remove them from the list
  final Set<String> _canceledDeliveryIds = {};

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    String? id;

    // Try Firebase Auth first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      id = currentUser.uid;
      print("✅ DeliveriesList: Got user from Firebase Auth: $id");
    }

    // If Firebase Auth returns null, try shared preferences
    if (id == null) {
      id = sharedPreferences?.getString("uid");
      print("✅ DeliveriesList: Got user from SharedPreferences: $id");
    }

    // If still null, wait for Firebase Auth
    if (id == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        id = refreshedUser.uid;
        print("✅ DeliveriesList: Got user after delay: $id");
      }
    }

    setState(() {
      userId = id;
      _isLoading = false;
    });

    if (id == null) {
      print("❌ DeliveriesList: No user ID found anywhere");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2B7B),
          title: const Text('My Deliveries'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userId == null || userId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2B7B),
          title: const Text('My Deliveries'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view your deliveries.',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B7B),
        title: const Text('My Deliveries'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: userId)
            .where('status', whereIn: [
          'pending',
          'searching',
          'accepted',
          'driver_on_pickup',
          'heading_to_destination',
          'in-progress',
        ])
            .snapshots(),
        builder: (context, snapshot) {
          // Loading indicator
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // If there are no active deliveries
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active deliveries.'));
          }

          final deliveries = snapshot.data!.docs;

          // Filter out canceled deliveries
          final filteredDeliveries = deliveries.where((delivery) {
            return !_canceledDeliveryIds.contains(delivery.id);
          }).toList();

          if (filteredDeliveries.isEmpty) {
            return const Center(child: Text('No active deliveries.'));
          }

          return Container(
            color: const Color(0xFFBCBDC2),
            child: ListView.builder(
              itemCount: filteredDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = filteredDeliveries[index];
                final rideType = delivery['vehicleType'] ?? 'Unknown';
                final status = delivery['status'] ?? 'unknown';
                final driverName = delivery['driverName'] ?? 'Not assigned';

                return Card(
                  color: const Color(0xFF1A2B7B),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.delivery_dining, color: Colors.green),
                    title: Text(rideType, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'Driver: $driverName\nStatus: $status',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70),
                    onTap: () async {
                      // Open the map tracking screen
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EnhancedDeliveryTrackingView(
                            deliveryData: delivery.data() as Map<String, dynamic>,
                            requestId: delivery.id,
                          ),
                        ),
                      );

                      // If delivery was cancelled, mark it for removal
                      if (result == 'cancelled') {
                        setState(() {
                          _canceledDeliveryIds.add(delivery.id);
                        });

                        // Show confirmation message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Delivery cancelled successfully'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}