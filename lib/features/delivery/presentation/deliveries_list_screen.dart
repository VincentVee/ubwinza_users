import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ubwinza_users/features/delivery/presentation/deliveries_tracking_view.dart';

class DeliveriesListScreen extends StatefulWidget {
  const DeliveriesListScreen({super.key});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  // Track canceled delivery IDs to remove them from the list
  final Set<String> _canceledDeliveryIds = {};

  @override
  Widget build(BuildContext context) {
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
          'driver_on_delivery',
          'in_progress',
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
                    title: Text(rideType),
                    subtitle: Text('Driver: $driverName\nStatus: $status'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
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