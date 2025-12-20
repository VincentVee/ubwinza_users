import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// --- 1. DATA MODELS ---

enum OrderStatus {
  pending,
  accepted,
  driverToPickup,         // Driver heading to the restaurant/pickup location
  onTheWayToYou,          // Driver heading to the customer/dropoff location
  delivered,              // Order complete
  cancelled,
  unknown,
}

class OrderItemModel {
  final String name;
  final int quantity;
  OrderItemModel({required this.name, required this.quantity});

  factory OrderItemModel.fromMap(Map<String, dynamic> data) {
    return OrderItemModel(
      name: data['name'] as String? ?? 'Unknown Item',
      quantity: (data['qty'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderModel {
  final String id;
  final OrderStatus status;
  final DateTime createdAt;
  final double total;
  final String sellerName;
  final List<OrderItemModel> items;
  final Map<OrderStatus, DateTime> statusHistory;

  OrderModel({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.sellerName,
    required this.items,
    required this.statusHistory,
  });

  factory OrderModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw Exception('Order data is null');

    // ------------------------------------------------------------------
    // CORRECTED STATUS PARSING (Direct Match)
    // ------------------------------------------------------------------
    final String statusString = data['status'] as String? ?? 'unknown';
    OrderStatus status = OrderStatus.unknown;

    for (var value in OrderStatus.values) {
      if (value.name == statusString) {
        status = value;
        break;
      }
    }
    // ------------------------------------------------------------------

    // --- Items parsing ---
    final List<dynamic> itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
        .toList();

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // ------------------------------------------------------------------
    // STATUS HISTORY CREATION (Conceptual/Simulated for Timeline)
    // NOTE: In a production app, fetch actual timestamps from Firestore.
    // ------------------------------------------------------------------
    final Map<OrderStatus, DateTime> history = {};

    // 1. Order Placed
    history[OrderStatus.pending] = createdAt;

    // 2. Accepted
    if (status.index >= OrderStatus.accepted.index) {
      history[OrderStatus.accepted] = history[OrderStatus.pending]?.add(const Duration(minutes: 5)) ?? createdAt.add(const Duration(minutes: 5));
    }

    // 3. Driver to Pickup
    if (status.index >= OrderStatus.driverToPickup.index) {
      history[OrderStatus.driverToPickup] = history[OrderStatus.accepted]?.add(const Duration(minutes: 10)) ?? createdAt.add(const Duration(minutes: 15));
    }

    // 4. On The Way To You
    if (status.index >= OrderStatus.onTheWayToYou.index) {
      history[OrderStatus.onTheWayToYou] = history[OrderStatus.driverToPickup]?.add(const Duration(minutes: 15)) ?? createdAt.add(const Duration(minutes: 30));
    }

    // 5. Delivered
    if (status.index >= OrderStatus.delivered.index) {
      history[OrderStatus.delivered] = history[OrderStatus.onTheWayToYou]?.add(const Duration(minutes: 5)) ?? createdAt.add(const Duration(minutes: 35));
    }
    // ------------------------------------------------------------------


    return OrderModel(
      id: doc.id,
      status: status,
      createdAt: createdAt,
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      sellerName: (data['seller'] as Map<String, dynamic>?)?['name'] as String? ?? 'N/A',
      items: items,
      statusHistory: history,
    );
  }
}

// --- 2. THE MAIN SCREEN (Unchanged) ---

class OrdersHistoryScreen extends StatelessWidget {
  const OrdersHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        appBar: _CustomAppBar(title: 'My Orders'),
        body: Center(child: Text('Please log in.', style: TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const _CustomAppBar(title: 'My Orders'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('You have no orders.', style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          final orders = docs.map(OrderModel.fromFirestore).toList();

          return SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return _OrderCard(order: orders[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

// --- 3. THE BEAUTIFUL CARD WIDGET ---

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  // Helper to format status text (e.g., driverToPickup -> Driver To Pickup)
  String _formatStatus(OrderStatus status) {
    return status.name.replaceAllMapped(
      RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
    ).trim().toUpperCase();
  }

  // Helper to determine status color
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return Colors.green.shade600;
      case OrderStatus.cancelled:
        return Colors.red.shade600;
      case OrderStatus.driverToPickup:
      case OrderStatus.onTheWayToYou:
        return Colors.blue.shade600;
      case OrderStatus.accepted:
        return Colors.orange.shade600;
      case OrderStatus.pending:
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tracking is active from 'driverToPickup' up to, but not including, 'delivered'
    final isTrackable = order.status.index >= OrderStatus.driverToPickup.index &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;

    return Card(
      color: Color(0xFF1A2B7B),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header: Seller Name & Status Badge ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.sellerName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    _formatStatus(order.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.black12),

            // ------------------------------------------------------
            // TIME-BASED STATUS TIMELINE
            // ------------------------------------------------------
            const Text(
              'Order Milestones:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),

            _OrderTimeline(order: order),

            const SizedBox(height: 12),
            // ------------------------------------------------------

            // --- Item Summary ---
            Text(
              order.items.map((i) => '${i.quantity}x ${i.name}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // --- Footer: Date and Total ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d, yyyy h:mm a').format(order.createdAt),
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                Text(
                  'Total: \K${order.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),

            // --- TRACKING FEATURE (Conditional Button) ---
            if (isTrackable) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => _TrackingScreen(orderId: order.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on_outlined, size: 24),
                  label: const Text(
                    'Track Driver Live',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- NEW WIDGET: Mini Timeline ---

class _OrderTimeline extends StatelessWidget {
  final OrderModel order;
  const _OrderTimeline({required this.order});

  static const List<OrderStatus> _progressSteps = [
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.driverToPickup,
    OrderStatus.onTheWayToYou,
    OrderStatus.delivered,
  ];

  String _getStepLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return 'Order Placed';
      case OrderStatus.accepted: return 'Order Confirmed';
      case OrderStatus.driverToPickup: return 'Driver Heading to Restaurant';
      case OrderStatus.onTheWayToYou: return 'On The Way To You';
      case OrderStatus.delivered: return 'Delivered';
      default: return status.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _progressSteps.map((stepStatus) {
        final timestamp = order.statusHistory[stepStatus];

        // Hide steps that haven't occurred and are not the current status
        if (timestamp == null && order.status.index < stepStatus.index) {
          return const SizedBox.shrink();
        }

        final bool isCompleted = timestamp != null;
        final bool isCurrent = order.status == stepStatus && !isCompleted;

        // Color Logic: Green for Completed, Blue for Current
        final Color circleColor = isCompleted
            ? Colors.green
            : isCurrent ? Colors.blue : Colors.grey.shade400;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Timeline Circle and Connector
            Column(
              children: [
                CircleAvatar(
                  radius: 8,
                  backgroundColor: circleColor,
                ),
                if (stepStatus != _progressSteps.last)
                  Container(
                    width: 2,
                    height: 30,
                    color: isCompleted ? Colors.green.shade200 : Colors.grey.shade200,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 2. Step Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStepLabel(stepStatus),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCompleted || isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted || isCurrent ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),

              ],
            ),
          ],
        );
      }).toList(),
    );
  }
}

// --- 4. NAVIGATION TARGET (Simulated Tracking Screen - Unchanged) ---

class _TrackingScreen extends StatelessWidget {
  final String orderId;
  const _TrackingScreen({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Order #$orderId'),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pin_drop, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                'Live map view for tracking your driver would go here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text('Order ID: $orderId'),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Widgets (Unchanged) ---

class _CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _CustomAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      centerTitle: true,
      backgroundColor: const Color(0xFF1A2B7B),
      elevation: 4,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}