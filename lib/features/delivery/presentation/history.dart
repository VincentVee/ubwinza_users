import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  static const Color primaryColor = Color(0xFF1A2B7B); // Ubwinza Blue
  static const Color accentColor = Color(0xFFE5A831); // A contrasting color

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view your history.',
              style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Delivery History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Fetch only deliveries where the status is 'delivered'
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'delivered') // Filter for completed deliveries
            .orderBy('completedAt', descending: true) // Show newest first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryColor)));
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading history: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text(
                    'No completed deliveries yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return SafeArea(child: HistoryCard(deliveryData: data));
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------
// WIDGET FOR SINGLE HISTORY ITEM
// -------------------------------------------------------------------

class HistoryCard extends StatelessWidget {
  final Map<String, dynamic> deliveryData;
  static const Color primaryColor = Color(0xFF1A2B7B);
  static const Color accentColor = Color(0xFFE5A831);

  const HistoryCard({super.key, required this.deliveryData});

  // Helper to format timestamps gracefully
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
    }
    return 'N/A';
  }

  // Helper to get the correct icon for vehicle type
  IconData _getVehicleIcon(String? vehicleType) {
    if (vehicleType?.toLowerCase() == 'motorbike') {
      return Icons.two_wheeler;
    } else if (vehicleType?.toLowerCase() == 'bicycle') {
      return Icons.directions_bike;
    }
    return Icons.local_shipping;
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract data, providing defaults
    final String driverName = deliveryData['driverName'] ?? 'Unknown Driver';
    final String driverImage = deliveryData['driverImage'] ?? '';
    final String pickupAddress = deliveryData['pickupAddress'] ?? 'Pickup Location';
    final String destinationAddress = deliveryData['destinationAddress'] ?? 'Delivery Destination';
    final double finalFare = (deliveryData['actualFare'] ?? deliveryData['estimatedFare'] ?? 0.0).toDouble();
    final String vehicleModel = deliveryData['vehicleModel'] ?? 'Vehicle';
    final String licensePlate = deliveryData['licensePlate'] ?? 'N/A';
    final String vehicleType = deliveryData['vehicleType'] ?? 'Unknown';
    final dynamic completedAt = deliveryData['completedAt'];

    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 20),
      color: primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Header and Fare ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Completed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(completedAt),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'K${finalFare.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 25, thickness: 1),

            // --- 2. Route Summary ---
            _buildRouteLine(
              icon: Icons.circle,
              iconColor: Colors.green,
              title: 'Pickup',
              address: pickupAddress,
              isFirst: true,
            ),
            _buildRouteLine(
              icon: Icons.location_on,
              iconColor: Colors.red,
              title: 'Dropoff',
              address: destinationAddress,
              isLast: true,
            ),

            const Divider(height: 25, thickness: 1),

            // --- 3. Driver & Vehicle Details ---
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: driverImage.isNotEmpty ? NetworkImage(driverImage) : null,
                  child: driverImage.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(_getVehicleIcon(vehicleType), size: 16, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            '$vehicleModel ($licensePlate)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Optional: Driver Rating Display
                // You can fetch the driver's actual rating here if stored elsewhere
                // For demonstration, displaying a static rating bar
                //
                // if (deliveryData.containsKey('userRating'))
                //   FlutterRatingBarIndicator(
                //     rating: (deliveryData['userRating'] as double?) ?? 5.0,
                //     itemBuilder: (context, index) => const Icon(
                //       Icons.star,
                //       color: accentColor,
                //     ),
                //     itemCount: 5,
                //     itemSize: 18.0,
                //     direction: Axis.horizontal,
                //   ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteLine({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and Connector Line
          SizedBox(
            width: 30,
            child: Column(
              children: [
                SizedBox(height: isFirst ? 0 : 4),
                Icon(icon, size: 18, color: iconColor),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 30, // Adjust height to control spacing
                    color: Colors.grey[300],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Title and Address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// HOW TO USE IT (Example in main.dart)
// -------------------------------------------------------------------

/*
void main() {
  // Ensure Firebase is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(); // Assuming this is done elsewhere
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ubwinza Deliveries',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A2B7B),
        useMaterial3: true,
      ),
      home: const DeliveryHistoryPage(), // Set as the entry point for testing
    );
  }
}
*/