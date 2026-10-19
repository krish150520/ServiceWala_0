import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/chat/chat_screen.dart';
import 'package:service_wala_business/screens/navigation/navigation_screen.dart';
import 'package:service_wala_business/screens/calling/calling_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/widgets/agent_booking_tracking_map.dart';
import 'package:intl/intl.dart';

/// Full job detail screen with progress tracking
class JobDetailScreen extends StatefulWidget {
  final Booking booking;

  const JobDetailScreen({super.key, required this.booking});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Booking _booking;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _resolveCustomerDetails();
    _subscribeRealtimeBooking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().refreshBooking(widget.booking.id).then((b) {
          if (mounted && b != null) {
            setState(() => _booking = b);
            _resolveCustomerDetails();
          }
        });
      }
    });
  }

  void _subscribeRealtimeBooking() {
    try {
      _realtimeChannel = SupabaseService.client
          .channel('public:agent_booking:${widget.booking.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.booking.id,
            ),
            callback: (payload) {
              if (mounted) {
                context.read<AppState>().refreshBooking(widget.booking.id).then((b) {
                  if (mounted && b != null) {
                    setState(() => _booking = b);
                    _resolveCustomerDetails();
                  }
                });
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[JobDetailScreen] Realtime subscribe notice: $e');
    }
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      try {
        SupabaseService.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  bool _isUpdatingStatus = false;

  Future<void> _resolveCustomerDetails() async {
    String? custId = _booking.customerId;
    if (custId == null || custId.isEmpty) {
      try {
        final bRow = await SupabaseService.client
            .from('bookings')
            .select('customer_id')
            .eq('id', _booking.id)
            .maybeSingle();
        custId = bRow?['customer_id']?.toString();
      } catch (_) {}
    }

    if (custId != null && custId.isNotEmpty) {
      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', custId)
            .maybeSingle();

        if (userRow != null && mounted) {
          final name = (userRow['full_name'] ??
                  userRow['name'] ??
                  userRow['display_name'])
              ?.toString()
              .trim();
          final phone = (userRow['phone'] ??
                  userRow['phone_number'] ??
                  userRow['mobile'])
              ?.toString()
              .trim();

          if ((name != null && name.isNotEmpty && name.toLowerCase() != 'customer') ||
              (phone != null && phone.isNotEmpty)) {
            setState(() {
              _booking = _booking.copyWith(
                customerId: custId,
                customerName: (name != null &&
                        name.isNotEmpty &&
                        name.toLowerCase() != 'customer')
                    ? name
                    : _booking.customerName,
                customerPhone: phone ?? _booking.customerPhone,
              );
            });
          }
        }
      } catch (e) {
        debugPrint('[JobDetailScreen] Customer detail resolution notice: $e');
      }
    }
  }

  void _refreshBooking() {
    final appState = context.read<AppState>();
    final updated = appState.bookings.where((b) => b.id == _booking.id);
    if (updated.isNotEmpty) {
      setState(() => _booking = updated.first);
      _resolveCustomerDetails();
    }
  }

  Future<void> _showSetPriceDialog() async {
    final priceController = TextEditingController(
      text: _booking.agreedPrice != null
          ? _booking.agreedPrice!.toStringAsFixed(0)
          : '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Set Negotiated Price'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the final agreed service charges negotiated with the customer on inspection:',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Agreed Price (INR)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter price';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final price = double.parse(priceController.text.trim());
                Navigator.pop(ctx);
                final appState = context.read<AppState>();
                final success = await appState.setBookingPrice(
                  _booking.id,
                  price,
                );
                _refreshBooking();
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Agreed price set to ₹${price.toStringAsFixed(0)}',
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appState.error ?? 'Failed to update agreed price.',
                        ),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save Price'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJobCompletionSettlementDialog() async {
    final double initialAmount = (_booking.agreedPrice != null && _booking.agreedPrice! > 0)
        ? _booking.agreedPrice!
        : 500.0;
    final priceController = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '500',
    );
    PaymentMethod selectedMethod = PaymentMethod.cash;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) {
          final isCash = selectedMethod == PaymentMethod.cash;
          const quickAmounts = [200, 350, 500, 800, 1000, 1500];

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
            contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
            actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (isCash ? const Color(0xFF10B981) : AppColors.primary)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: isCash ? const Color(0xFF10B981) : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Job Completed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select payment mode to settle',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment mode selection (Cash vs UPI)
                  const Text(
                    'How is Customer Paying?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option A: Cash
                  InkWell(
                    onTap: () => setDialogState(() => selectedMethod = PaymentMethod.cash),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCash
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCash ? const Color(0xFF10B981) : AppColors.border,
                          width: isCash ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCash
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.payments_rounded,
                              color: isCash ? const Color(0xFF10B981) : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash Payment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Customer pays cash directly in hand',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isCash ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isCash ? const Color(0xFF10B981) : AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Option B: UPI / Online
                  InkWell(
                    onTap: () => setDialogState(() => selectedMethod = PaymentMethod.razorpay),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !isCash
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !isCash ? AppColors.primary : AppColors.border,
                          width: !isCash ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: !isCash
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              color: !isCash ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPI / Online (Razorpay)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Customer app shows pop-up to pay ₹X online',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            !isCash ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !isCash ? AppColors.primary : AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Amount input
                  Text(
                    isCash ? 'Cash Amount Collected (₹)' : 'Enter UPI Amount to Request (₹)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isCash ? const Color(0xFF10B981) : AppColors.primary,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick amount selector chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickAmounts.map((q) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            priceController.text = q.toString();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '₹$q',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Dynamic contextual prompt card
                  if (!isCash) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.phonelink_ring_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Submitting will send a notification and immediately trigger a payment pop-up on the Customer\'s app to pay via UPI or cards.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The job will immediately be marked as Completed and credited to your earnings.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final enteredAmount = double.tryParse(priceController.text.trim());
                  if (enteredAmount == null || enteredAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount greater than ₹0.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  final appState = context.read<AppState>();
                  Navigator.pop(ctx);
                  setState(() => _isUpdatingStatus = true);

                  try {
                    if (isCash) {
                      // 1. If Cash: Save price, confirm cash received, and complete booking
                      await appState.confirmCashPayment(_booking.id, enteredAmount);
                      await appState.updateBookingStatus(_booking.id, BookingStatus.completed);
                      _refreshBooking();
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('🎉 Job completed! Received ₹${enteredAmount.toStringAsFixed(0)} in cash.'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      // 2. If UPI: Send payment request to customer app for ₹X
                      await appState.requestUpiPayment(_booking.id, enteredAmount);
                      _refreshBooking();
                      if (!mounted) return;
                      showDialog<void>(
                        context: context,
                        builder: (promptCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Payment Request Sent'),
                              ],
                            ),
                            content: Text(
                              'A payment pop-up of ₹${enteredAmount.toStringAsFixed(0)} has been sent to the Customer app.\n\nThe customer can now pay using UPI or cards on their phone.\n\nOnce payment is confirmed, this booking will automatically be marked completed.',
                              style: const TextStyle(fontSize: 13.5, height: 1.4),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(promptCtx),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error updating settlement: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isUpdatingStatus = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCash ? const Color(0xFF10B981) : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isCash ? 'Complete with Cash ✓' : 'Send UPI Request →',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(BookingStatus newStatus) async {
    if (_isUpdatingStatus) return;

    // Show settlement options for completing a job
    if (newStatus == BookingStatus.completed) {
      await _showJobCompletionSettlementDialog();
      return;
    }

    if (!mounted) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final appState = context.read<AppState>();
      final messenger = ScaffoldMessenger.of(context);
      final success = await appState.updateBookingStatus(
        _booking.id,
        newStatus,
      );
      _refreshBooking();

      if (mounted) {
        final infoMsg = appState.statusInfoMessage;
        if (infoMsg != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('ℹ️ $infoMsg'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                newStatus == BookingStatus.completed
                    ? '🎉 Job completed successfully! Settlement recorded.'
                    : '✅ Status updated: ${newStatus.label}',
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(appState.error ?? 'Failed to update job status.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _callCustomer() {
    CallingScreen.start(
      context: context,
      customerName: _booking.customerName,
      customerPhone: _booking.customerPhone,
      serviceTitle: _booking.serviceType,
      bookingId: _booking.id,
      customerId: _booking.customerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final latestBooking = appState.bookings.where(
          (b) => b.id == _booking.id,
        );
        if (latestBooking.isNotEmpty) {
          _booking = latestBooking.first;
        }

        final service = ServiceCategory.findById(_booking.serviceType);
        final isConfirmed =
            _booking.status != BookingStatus.accepted &&
            _booking.status != BookingStatus.pendingResponse;
        final isChatEligible = appState.isChatEligible(_booking);
        final isPendingOrAccepted =
            _booking.status == BookingStatus.pendingResponse ||
            _booking.status == BookingStatus.accepted;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Job Details'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async {
                  await appState.refreshBooking(_booking.id);
                  _refreshBooking();
                },
                tooltip: 'Refresh Job Details',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await appState.refreshBooking(_booking.id);
              _refreshBooking();
            },
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service & Status Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    service?.bgColor ?? AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                service?.icon ?? Icons.build_rounded,
                                color: service?.iconColor ?? AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service?.name ?? _booking.serviceType,
                                    style: AppTextStyles.headingSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Booking #${_booking.id.length >= 6 ? _booking.id.substring(_booking.id.length - 6) : _booking.id}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          _booking.description,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer & Appointment Details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          Icons.person_outline_rounded,
                          'Customer',
                          _booking.customerName,
                          trailing: const Icon(
                            Icons.verified,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _detailRow(
                          Icons.schedule_outlined,
                          'Appointment Schedule',
                          DateFormat(
                            'MMM d, yyyy • h:mm a',
                          ).format(_booking.appointmentTime),
                        ),
                        if (isConfirmed &&
                            _booking.customerAddress != null) ...[
                          const SizedBox(height: 16),
                          _detailRow(
                            Icons.location_on_outlined,
                            'Service Address',
                            _booking.customerAddress!,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _detailRow(
                          Icons.currency_rupee_rounded,
                          'Agreed Service Charge',
                          _booking.agreedPrice != null
                              ? '₹${_booking.agreedPrice!.toStringAsFixed(0)} (${_booking.paymentMethod.label})'
                              : 'Not set yet (Negotiate on site)',
                          trailing: !_booking.status.isCompleted
                              ? TextButton(
                                  onPressed: _showSetPriceDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _booking.agreedPrice != null
                                        ? 'Edit'
                                        : 'Set Price',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick action circular buttons (Call, Chat, Navigate)
                  if (isConfirmed && !_booking.status.isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          _actionButton(
                            Icons.phone_rounded,
                            'Call Customer',
                            AppColors.success,
                            _callCustomer,
                          ),
                          const SizedBox(width: 12),
                          _actionButton(
                            isChatEligible
                                ? Icons.chat_bubble_outline_rounded
                                : (isPendingOrAccepted
                                      ? Icons.lock_outline_rounded
                                      : Icons.chat_bubble_outline_rounded),
                            isPendingOrAccepted
                                ? 'Chat (Locked)'
                                : 'In-App Chat',
                            isChatEligible
                                ? AppColors.primary
                                : AppColors.textMuted,
                            () {
                              if (isPendingOrAccepted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _booking.status ==
                                              BookingStatus.pendingResponse
                                          ? '🔒 Chat is locked. Accept the request and wait for customer platform fee.'
                                          : '⏳ Chat is locked. Waiting for customer to pay the ₹9 platform fee.',
                                    ),
                                    backgroundColor: const Color(0xFFD97706),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(booking: _booking),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          _actionButton(
                            Icons.navigation_outlined,
                            'Navigate',
                            AppColors.primaryDark,
                            () async {
                              final navigator = Navigator.of(context);
                              if (_booking.status == BookingStatus.confirmed) {
                                await _updateStatus(BookingStatus.onTheWay);
                              }
                              if (!mounted) return;
                              await navigator.push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NavigationScreen(booking: _booking),
                                ),
                              );
                              if (mounted) {
                                _refreshBooking();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Interactive Live Customer Navigation & Map Tracking (Matching Cx app)
                    AgentBookingTrackingMap(
                      booking: _booking,
                      height: 300,
                      onArrivedPressed: () {
                        if (mounted) {
                          _refreshBooking();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Awaiting confirmation notice
                  if (_booking.status == BookingStatus.accepted)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Awaiting Customer Confirmation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Customer address and direct calling will unlock as soon as the booking is confirmed.",
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Job progress section
                  if (isConfirmed &&
                      !_booking.status.isCompleted &&
                      !_booking.status.isCancelled) ...[
                    const SizedBox(height: 16),
                    _buildProgressSection(),
                  ],

                  // Completed summary
                  if (_booking.status.isCompleted) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: AppColors.successLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 32,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Job Completed Successfully',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Great work! This job has been recorded and credited to your earnings.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_booking.agreedPrice != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              '₹${_booking.agreedPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSection() {
    // 1. Pending response state: show Accept & Decline actions
    if (_booking.status == BookingStatus.pendingResponse) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Incoming Request Awaiting Response',
                    style: AppTextStyles.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Accept this request to proceed. The customer will then confirm and pay the platform fee (₹9) before service starts.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () async {
                            setState(() => _isUpdatingStatus = true);
                            try {
                              final appState = context.read<AppState>();
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await appState.declineRequest(
                                _booking.id,
                              );
                              if (!mounted) return;
                              if (success) {
                                _refreshBooking();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Request declined.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      appState.error ??
                                          'Failed to decline request.',
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isUpdatingStatus = false);
                              }
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(
                        color: AppColors.error,
                        width: 0.8,
                      ),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () async {
                            setState(() => _isUpdatingStatus = true);
                            try {
                              final appState = context.read<AppState>();
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await appState.acceptRequest(
                                _booking.id,
                              );
                              if (!mounted) return;
                              if (success) {
                                _refreshBooking();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      '✅ Request accepted! Waiting for customer platform fee.',
                                    ),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      appState.error ??
                                          'Failed to accept request. Check permissions.',
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isUpdatingStatus = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdatingStatus
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Accept Request',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. Accepted state: Waiting for platform fee from customer
    if (_booking.status == BookingStatus.accepted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Waiting for Customer Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'You accepted this booking! The customer is now completing the ₹9 platform fee payment on the ServiceWala CX app. Once verified, this booking will automatically become Confirmed and navigation/arrival progress will unlock.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Declined or Cancelled
    if (_booking.status == BookingStatus.declined ||
        _booking.status == BookingStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This booking is ${_booking.status.label.toLowerCase()}.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      BookingStatus.confirmed,
      BookingStatus.onTheWay,
      BookingStatus.arrived,
      BookingStatus.workStarted,
      BookingStatus.completed,
    ];

    final currentIndex = steps.indexOf(_booking.status);
    final nextStatus = currentIndex < steps.length - 1
        ? steps[currentIndex + 1]
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Progress', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),

          // Progress steps
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isCompleted = index <= currentIndex;
            final isCurrent = index == currentIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: isCurrent
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : Icons.circle,
                          size: isCompleted ? 14 : 8,
                          color: isCompleted
                              ? Colors.white
                              : AppColors.textMuted,
                        ),
                      ),
                      if (index < steps.length - 1)
                        Container(
                          width: 2,
                          height: 26,
                          color: isCompleted
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Next step CTA button
          if (nextStatus != null) ...[
            if (_booking.paymentMethod == PaymentMethod.razorpay &&
                _booking.paymentStatus == PaymentStatus.pending &&
                nextStatus == BookingStatus.completed) ...[
              _buildUpiPendingBanner(),
            ] else ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isUpdatingStatus
                      ? null
                      : () => _updateStatus(nextStatus),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nextStatus == BookingStatus.completed
                        ? AppColors.success
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUpdatingStatus
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Updating status on server...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getNextStepIcon(nextStatus), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _getNextStepLabel(nextStatus),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
              if (_booking.status == BookingStatus.arrived) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isUpdatingStatus
                        ? null
                        : () => _showJobCompletionSettlementDialog(),
                    icon: const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    label: const Text(
                      'Job Completed',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.success, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildUpiPendingBanner() {
    final amount = _booking.agreedPrice ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UPI Payment Request Sent',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested ₹${amount.toStringAsFixed(0)} via Razorpay/UPI on Customer App',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUpdatingStatus
                      ? null
                      : () async {
                          setState(() => _isUpdatingStatus = true);
                          final b = await context.read<AppState>().refreshBooking(_booking.id);
                          if (mounted) {
                            setState(() {
                              if (b != null) _booking = b;
                              _isUpdatingStatus = false;
                            });
                            if (_booking.paymentStatus == PaymentStatus.paid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Payment confirmed! Job completed.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment is still pending on customer app.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Check Status', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUpdatingStatus
                      ? null
                      : () => _showJobCompletionSettlementDialog(),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Change Amount', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdatingStatus
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Switch to Cash Payment?'),
                          content: Text(
                            'Did customer pay ₹${amount.toStringAsFixed(0)} in cash instead of online UPI?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('No'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                              ),
                              child: const Text('Yes, Cash Received'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        setState(() => _isUpdatingStatus = true);
                        final appState = context.read<AppState>();
                        await appState.confirmCashPayment(_booking.id, amount.toDouble());
                        await appState.updateBookingStatus(_booking.id, BookingStatus.completed);
                        _refreshBooking();
                        setState(() => _isUpdatingStatus = false);
                      }
                    },
              icon: const Icon(Icons.payments_rounded, size: 16),
              label: const Text('Received Cash Instead', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color badgeBg;
    Color badgeText;

    switch (_booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.onTheWay:
      case BookingStatus.arrived:
      case BookingStatus.workStarted:
        badgeBg = AppColors.primaryLight;
        badgeText = AppColors.primary;
        break;
      case BookingStatus.completed:
        badgeBg = AppColors.successLight;
        badgeText = AppColors.success;
        break;
      default:
        badgeBg = AppColors.surfaceLight;
        badgeText = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _booking.status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: badgeText,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(value, style: AppTextStyles.labelMedium),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 4), trailing],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNextStepIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.onTheWay:
        return Icons.directions_car_rounded;
      case BookingStatus.arrived:
        return Icons.location_on_rounded;
      case BookingStatus.workStarted:
        return Icons.handyman_rounded;
      case BookingStatus.completed:
        return Icons.check_circle_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  String _getNextStepLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.onTheWay:
        return "I'm On The Way →";
      case BookingStatus.arrived:
        return "I've Arrived at Location";
      case BookingStatus.workStarted:
        return 'Start Service Work';
      case BookingStatus.completed:
        return 'Job Completed';
      default:
        return 'Next Step →';
    }
  }
}
