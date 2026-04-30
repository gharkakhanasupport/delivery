import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/database_service.dart';

/// Full-screen bottom sheet shown when a new pickup FCM arrives.
/// 30-second countdown → auto-dismiss if partner doesn't tap Accept/Skip.
///
/// Phase 5C richer card: kitchen addr, items, payment chip, earnings big/gold,
/// total muted, customer area only (privacy until Accept). Realtime-subscribes
/// to `order_taken:<orderId>`; auto-dismisses with snackbar if another partner
/// claims first.
class IncomingOrderSheet extends StatefulWidget {
  final String orderId;
  final String kitchenName;
  final String? kitchenAddress;
  final String? customerArea;
  final int itemCount;
  final String paymentMethod; // 'cash' or 'online'
  final double agentEarnings;
  final double totalAmount;
  final double? pickupLat;
  final double? pickupLng;
  final Future<bool> Function(String orderId) onAccept;

  const IncomingOrderSheet({
    super.key,
    required this.orderId,
    required this.kitchenName,
    required this.totalAmount,
    required this.agentEarnings,
    required this.itemCount,
    required this.paymentMethod,
    required this.onAccept,
    this.kitchenAddress,
    this.customerArea,
    this.pickupLat,
    this.pickupLng,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String kitchenName,
    required double totalAmount,
    required double agentEarnings,
    required int itemCount,
    required String paymentMethod,
    String? kitchenAddress,
    String? customerArea,
    double? pickupLat,
    double? pickupLng,
    required Future<bool> Function(String orderId) onAccept,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingOrderSheet(
        orderId: orderId,
        kitchenName: kitchenName,
        kitchenAddress: kitchenAddress,
        customerArea: customerArea,
        itemCount: itemCount,
        paymentMethod: paymentMethod,
        agentEarnings: agentEarnings,
        totalAmount: totalAmount,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        onAccept: onAccept,
      ),
    );
  }

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends State<IncomingOrderSheet> {
  static const _countdownSeconds = 30;
  int _secondsLeft = _countdownSeconds;
  Timer? _timer;
  bool _submitting = false;
  RealtimeChannel? _takenChannel;

  @override
  void initState() {
    super.initState();
    _playAlertFeedback();
    _startCountdown();
    _subscribeOrderTaken();
  }

  /// Vibration + system notification sound on sheet open.
  Future<void> _playAlertFeedback() async {
    // Heavy haptic pulse.
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();
    // Play default alert sound via system channel.
    SystemSound.play(SystemSoundType.alert);
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted && !_submitting) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  /// Listen for `order_taken` broadcast. If another partner claims this
  /// order first, dismiss sheet + show snackbar.
  void _subscribeOrderTaken() {
    try {
      final db = DatabaseService().primary;
      final ch = db.channel('order_taken:${widget.orderId}');
      ch.onBroadcast(
        event: 'taken',
        callback: (payload) {
          final takenId = payload['order_id']?.toString();
          if (takenId != widget.orderId) return;
          if (!mounted || _submitting) return;
          _timer?.cancel();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order already taken by another partner'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
      ch.subscribe();
      _takenChannel = ch;
    } catch (e) {
      debugPrint('[IncomingOrderSheet] realtime subscribe failed: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_takenChannel != null) {
      try {
        DatabaseService().primary.removeChannel(_takenChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    final won = await widget.onAccept(widget.orderId);
    if (!mounted) return;

    Navigator.of(context).pop();
    if (!won) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order already taken by another partner')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / _countdownSeconds;
    final isCash = widget.paymentMethod.toLowerCase() == 'cash';
    final shortId = widget.orderId.length >= 4
        ? widget.orderId.substring(0, 4).toUpperCase()
        : widget.orderId.toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Countdown ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: AppColors.borderSubtle,
                  valueColor: AlwaysStoppedAnimation(
                    progress > 0.3 ? AppColors.emeraldGreen : AppColors.error,
                  ),
                ),
              ),
              Text(
                '$_secondsLeft',
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'New pickup  •  #$shortId',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Order card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kitchen
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.restaurant, color: AppColors.emeraldGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.kitchenName,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.kitchenAddress != null &&
                              widget.kitchenAddress!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.kitchenAddress!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Customer area (privacy — no full address until Accept)
                if (widget.customerArea != null &&
                    widget.customerArea!.trim().isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Drop: ${widget.customerArea}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Chips row: items + payment
                Row(
                  children: [
                    _chip(
                      icon: Icons.shopping_bag_outlined,
                      label:
                          '${widget.itemCount} item${widget.itemCount == 1 ? '' : 's'}',
                      bg: AppColors.lightCard,
                      fg: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    _chip(
                      icon:
                          isCash ? Icons.payments_outlined : Icons.credit_card,
                      label: isCash ? 'Cash' : 'Online',
                      bg: isCash
                          ? AppColors.goldenMustard.withValues(alpha: 0.15)
                          : AppColors.accentBlue.withValues(alpha: 0.12),
                      fg: isCash
                          ? AppColors.goldenMustardDark
                          : AppColors.accentBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Earnings (big gold) + Total (muted)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'You earn',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(Icons.currency_rupee,
                                size: 22, color: AppColors.goldenMustard),
                            Text(
                              widget.agentEarnings.toStringAsFixed(0),
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.goldenMustard,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Order value',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          '₹${widget.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldGreen,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Accept',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
