import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/payout_service.dart';

/// Payout history — lists payout_requests for current agent.
class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  final _service = PayoutService();

  Color _statusColor(String s) {
    switch (s) {
      case 'processed':
        return AppColors.emeraldGreen;
      case 'processing':
      case 'queued':
        return Colors.blueAccent;
      case 'failed':
      case 'reversed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Payouts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.emeraldGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Manual payouts',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text(
                        'Admin transfers earnings to your UPI/bank. You will see payment reference once paid.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.streamMyPayouts(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No payouts yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Your daily payouts will show here',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final p = list[i];
                    final status = (p['status'] ?? '').toString();
                    final amount = ((p['amount_paise'] ?? 0) as num) / 100.0;
                    final created = DateTime.tryParse(p['created_at'] ?? '');
                    final mode = (p['mode'] ?? '').toString();
                    final reason = (p['failure_reason'] ?? '').toString();
                    final ref = (p['payment_reference'] ?? '').toString();
                    final when = created == null
                        ? ''
                        : '${created.day}/${created.month}/${created.year} '
                            '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '\u20B9${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (mode.isNotEmpty) ...[
                                Icon(Icons.swap_horiz, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(mode, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                const SizedBox(width: 10),
                              ],
                              Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(when, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          if (ref.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.receipt, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text('Ref: $ref',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ],
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(reason,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
