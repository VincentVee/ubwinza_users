import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeliveriesTrackingView extends StatelessWidget {
  const DeliveriesTrackingView({super.key});

  int _statusIndex(String? status) {
    switch (status) {
      case 'driver_on_pickup':
        return 0;
      case 'driver_on_delivery':
        return 1;
      case 'delivered':
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No user logged in.',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Deliveries',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2B7B),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: userId)
            .where('driverId', isNotEqualTo: null) // only those with driver assigned
            .where('status', whereIn: [
              'driver_accepted',
              'driver_on_pickup',
              'driver_on_delivery'
            ])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading deliveries: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no active deliveries.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // We’ll show only the most recent delivery for simplicity
          final delivery = docs.first;
          final status = delivery['status'] ?? 'pending';

          final List<Map<String, dynamic>> steps = [
            {
              'label': 'Driver on the way to pick up your package',
              'icon': Icons.directions_car
            },
            {
              'label': 'Driver on the way to deliver to you',
              'icon': Icons.delivery_dining
            },
            {
              'label': 'Delivered',
              'icon': Icons.check_circle_outline
            },
          ];

          final currentStep = _statusIndex(status);

          return Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Delivery Progress',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2B7B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Column(
                          children: List.generate(steps.length, (index) {
                            final isActive = index <= currentStep;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isActive
                                          ? Colors.green
                                          : Colors.grey[300],
                                      child: Icon(
                                        steps[index]['icon'] as IconData,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    if (index != steps.length - 1)
                                      Container(
                                        width: 3,
                                        height: 50,
                                        color: isActive
                                            ? Colors.green
                                            : Colors.grey[300],
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      steps[index]['label'] as String,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: isActive
                                            ? Colors.black
                                            : Colors.grey,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
