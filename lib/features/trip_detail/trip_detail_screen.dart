import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/repositories/trip_repository.dart';
import '../../models/trip.dart';
import 'driver_arriving_map_demo.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  StreamSubscription<Trip?>? _subscription;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final repo = context.read<TripRepository>();
    _subscription = repo.watchTrip(widget.tripId).listen((trip) {
      if (trip != null && trip.status != _lastStatus) {
        _handleStatusChange(trip.status);
        _lastStatus = trip.status;
      }
    });
  }

  void _handleStatusChange(String status) {
    String title = 'Cập nhật chuyến xe';
    String body = '';

    switch (status) {
      case TripStatuses.accepted:
        body = 'Tài xế đã nhận chuyến của bạn!';
        break;
      case TripStatuses.driverArriving:
        body = 'Tài xế đang trên đường đến điểm đón.';
        break;
      case TripStatuses.inProgress:
        body = 'Chuyến xe đã bắt đầu. Chúc bạn một chuyến đi an toàn!';
        break;
      case TripStatuses.completed:
        body = 'Chuyến xe hoàn thành. Cảm ơn bạn đã sử dụng dịch vụ!';
        break;
      case TripStatuses.cancelled:
        body = 'Chuyến xe đã bị hủy.';
        break;
    }

    if (body.isNotEmpty) {
      NotificationService.showNotification(
        id: widget.tripId.hashCode,
        title: title,
        body: body,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  static String _statusLabel(String s) {
    switch (s) {
      case TripStatuses.findingDriver:
        return 'Đang tìm tài xế';
      case TripStatuses.accepted:
        return 'Tài xế đã nhận';
      case TripStatuses.driverArriving:
        return 'Tài xế đang đến điểm đón';
      case TripStatuses.inProgress:
        return 'Đang di chuyển tới điểm đến';
      case TripStatuses.completed:
        return 'Hoàn thành';
      case TripStatuses.cancelled:
        return 'Đã hủy';
      default:
        return s;
    }
  }

  static String _vehicleLabel(String v) {
    return v == VehicleTypes.car ? 'Ô tô' : 'Xe máy';
  }

  Future<void> _showRatingDialog(Trip trip) async {
    int localRating = 5;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Đánh giá chuyến đi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bạn thấy chuyến đi thế nào?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < localRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => localRating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Nhập nhận xét (tùy chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bỏ qua'),
            ),
            FilledButton(
              onPressed: () {
                context.read<TripRepository>().updateRating(
                      widget.tripId,
                      localRating,
                      commentController.text.trim(),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cảm ơn bạn đã đánh giá!')),
                );
              },
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TripRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết chuyến')),
      body: StreamBuilder<Trip?>(
        stream: repo.watchTrip(widget.tripId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final trip = snapshot.data;
          if (trip == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                title: const Text('Mã chuyến'),
                subtitle: SelectableText(trip.id ?? widget.tripId),
              ),
              ListTile(
                title: const Text('Trạng thái'),
                subtitle: Text(_statusLabel(trip.status)),
              ),
              if (trip.status == TripStatuses.driverArriving ||
                  trip.status == TripStatuses.accepted) ...[
                DriverArrivingMapDemo(
                  key: ValueKey(
                    '${trip.pickupLat}_${trip.pickupLng}_'
                    '${trip.dropoffLat}_${trip.dropoffLng}',
                  ),
                  pickup: LatLng(trip.pickupLat, trip.pickupLng),
                  dropoff: LatLng(trip.dropoffLat, trip.dropoffLng),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vị trí xe (demo, lặp lại)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_filled,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            trip.status == TripStatuses.driverArriving
                                ? 'Demo: tài xế đã nhận cuốc và đang di chuyển tới chỗ bạn.'
                                : 'Demo: chuyến đã được nhận; có thể bấm bước tiếp theo để mô phỏng tài xế tới điểm đón.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ListTile(
                title: const Text('Loại xe'),
                subtitle: Text(_vehicleLabel(trip.vehicleType)),
              ),
              ListTile(
                title: const Text('Khoảng cách'),
                subtitle: Text('${trip.distanceKm.toStringAsFixed(2)} km'),
              ),
              ListTile(
                title: const Text('Giá'),
                subtitle: Text('${trip.priceVnd.toString()} đ'),
              ),
              if (trip.status == TripStatuses.completed && trip.rating != null)
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.stars, color: Colors.amber),
                    title: const Text('Đánh giá của bạn'),
                    subtitle: Text('${trip.rating} sao - ${trip.comment ?? ""}'),
                  ),
                ),
              ListTile(
                title: const Text('Điểm đón'),
                subtitle: Text(
                  '${trip.pickupLat.toStringAsFixed(5)}, ${trip.pickupLng.toStringAsFixed(5)}',
                ),
              ),
              ListTile(
                title: const Text('Điểm đến'),
                subtitle: Text(
                  '${trip.dropoffLat.toStringAsFixed(5)}, ${trip.dropoffLng.toStringAsFixed(5)}',
                ),
              ),
              const SizedBox(height: 16),
              if (trip.status == TripStatuses.findingDriver)
                FilledButton(
                  onPressed: () async {
                    await repo.updateStatus(
                      widget.tripId,
                      TripStatuses.driverArriving,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tài xế đã nhận chuyến — đang đến điểm đón (demo).',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Giả lập: tài xế nhận & đang đến'),
                ),
              if (trip.status == TripStatuses.driverArriving ||
                  trip.status == TripStatuses.accepted) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    await repo.updateStatus(widget.tripId, TripStatuses.inProgress);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã đón khách — đang di chuyển tới điểm đến (demo).',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Giả lập: đã đến đón — bắt đầu chuyến'),
                ),
              ],
              if (trip.status == TripStatuses.inProgress) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () async {
                    await repo.updateStatus(
                      widget.tripId,
                      TripStatuses.completed,
                    );
                    if (mounted) {
                      _showRatingDialog(trip);
                    }
                  },
                  child: const Text('Giả lập: hoàn thành chuyến'),
                ),
              ],
              if (trip.status == TripStatuses.completed && trip.rating == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showRatingDialog(trip),
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Viết đánh giá'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
