import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrdersTrackingView extends StatelessWidget {
  const OrdersTrackingView({super.key});

  /// Map backend status → progress index
  int _statusIndex(String status) {
    switch (status) {
      case 'pending':
        return 0; // Order placed
      case 'preparing':
        return 1; // Seller preparing
      case 'onTheWay':
        return 2; // Rider on way
      case 'delivered':
        return 3; // Delivered
      case 'cancelled':
        return -1; // Special case (cancelled)
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
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2B7B),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no active orders.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final order = docs.first;
          final status = (order['status'] ?? 'pending') as String;
          final currentStep = _statusIndex(status);

          /// Define the timeline steps
          final List<Map<String, dynamic>> steps = [
            {'label': 'Order placed', 'icon': Icons.receipt_long},
            {'label': 'Preparing your order', 'icon': Icons.kitchen},
            {'label': 'On the way', 'icon': Icons.delivery_dining},
            {'label': 'Delivered', 'icon': Icons.check_circle_outline},
          ];

          /// If the order was cancelled, show a red message instead of steps
          if (currentStep == -1) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  color: Colors.red.shade50,
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cancel, color: Colors.red, size: 50),
                        SizedBox(height: 16),
                        Text(
                          'This order was cancelled by the seller.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  color: const Color(0xFF1A2B7B),
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
                            'Order Progress',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
                                          : const Color.fromARGB(
                                              255, 122, 120, 120),
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
                                            ? Colors.green
                                            : Colors.grey[400],
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
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Current Status: ${status.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
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
