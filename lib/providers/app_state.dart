import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/core/config/supabase_config.dart';
import 'package:service_wala_business/core/constants/database_constants.dart';
import 'package:service_wala_business/core/errors/app_exception.dart';
import 'package:service_wala_business/core/services/supabase_service.dart';
import 'package:service_wala_business/data/models/booking_model.dart';
import 'package:service_wala_business/data/models/earnings_model.dart';
import 'package:service_wala_business/data/models/payment_model.dart';
import 'package:service_wala_business/data/models/provider_model.dart';
import 'package:service_wala_business/data/repositories/auth_repository.dart';
import 'package:service_wala_business/data/repositories/booking_repository.dart';
import 'package:service_wala_business/data/repositories/chat_repository.dart';
import 'package:service_wala_business/data/repositories/device_token_repository.dart';
import 'package:service_wala_business/data/repositories/earnings_repository.dart';
import 'package:service_wala_business/data/repositories/payment_repository.dart';
import 'package:service_wala_business/data/repositories/profile_repository.dart';
import 'package:service_wala_business/data/repositories/provider_repository.dart';
import 'package:service_wala_business/models/agent_profile.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/chat_message.dart';
import 'package:service_wala_business/models/service_request.dart';
import 'package:service_wala_business/models/transaction.dart';
import 'package:service_wala_business/core/services/incoming_call_manager.dart';
import 'package:service_wala_business/core/services/notification_sender_service.dart';
import 'package:service_wala_business/services/mock_data_service.dart';
import 'package:service_wala_business/services/agent_location_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central application state management bridging Supabase repositories and demo mode.
class AppState extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  final ProviderRepository _providerRepo = ProviderRepository();
  final BookingRepository _bookingRepo = BookingRepository();
  final EarningsRepository _earningsRepo = EarningsRepository();
  final ProfileRepository _profileRepo = ProfileRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final ChatRepository _chatRepo = ChatRepository();

  EarningsRepository get earningsRepo => _earningsRepo;

  sp.RealtimeChannel? _bookingsChannel;
  sp.RealtimeChannel? _messagesChannel;
  final Map<String, String> _conversationIds = {};
  final Map<String, sp.RealtimeChannel> _chatChannels = {};
  final Map<String, int> _unreadCounts =
      {}; // bookingId -> unread customer message count

  // Auth & Session State
  bool _isLoggedIn = false;
  bool _isLoading = false;
  bool _isDemoMode = true;
  bool _isNewUser = false;
  String? _error;

  // Agent / Provider Profile
  AgentProfile? _agent;
  String? _providerId; // Supabase providers.id (distinct from auth.uid())

  // Data Collections
  List<ServiceRequest> _serviceRequests = [];
  List<Booking> _bookings = [];
  List<Transaction> _transactions = [];
  List<ChatMessage> _chatMessages = [];
  EarningsSummary _earningsSummary = EarningsSummary.empty();

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isDemoMode => _isDemoMode;
  bool get isNewUser => _isNewUser;
  String? get error => _error;
  AgentProfile? get agent => _agent;
  String? get providerId => _providerId;
  List<ServiceRequest> get serviceRequests => _serviceRequests;
  List<Booking> get bookings => _bookings;
  List<Transaction> get transactions => _transactions;
  EarningsSummary get earningsSummary => _earningsSummary;

  int get totalUnreadCount =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);
  int getUnreadCount(String bookingId) => _unreadCounts[bookingId] ?? 0;
  bool hasExistingConversation(String bookingId) {
    if (_isDemoMode) return true;
    if (_conversationIds.containsKey(bookingId)) return true;
    final booking = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (booking != null) {
      return findExistingConversationForCustomer(booking) != null;
    }
    return false;
  }

  String? getConversationIdForBooking(String bookingId) {
    if (_conversationIds.containsKey(bookingId)) {
      return _conversationIds[bookingId];
    }
    final booking = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (booking != null) {
      return findExistingConversationForCustomer(booking);
    }
    return null;
  }

  // Status transition messaging and duplicate mutation guard
  String? _statusInfoMessage;
  String? get statusInfoMessage => _statusInfoMessage;
  void clearStatusInfoMessage() {
    _statusInfoMessage = null;
  }

  final Set<String> _inFlightStatusUpdates = {};
  bool isUpdatingBookingStatus(String bookingId) =>
      _inFlightStatusUpdates.contains(bookingId);

  // ============================
  // Lifecycle Booking Categories
  // ============================

  /// 1. Incoming Requests awaiting Agent acceptance (status: 'pending' / 'pending_response')
  List<Booking> get incomingRequests {
    return _bookings
        .where((b) => b.status == BookingStatus.pendingResponse)
        .toList();
  }

  /// 2. Accepted Jobs awaiting Customer ₹9 platform fee (status: 'accepted')
  List<Booking> get acceptedJobs {
    return _bookings.where((b) => b.status == BookingStatus.accepted).toList();
  }

  /// 3. Confirmed & In-Progress Jobs (status: 'confirmed', 'onTheWay', 'arrived', 'workStarted')
  List<Booking> get confirmedJobs {
    return _bookings
        .where(
          (b) =>
              b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.onTheWay ||
              b.status == BookingStatus.arrived ||
              b.status == BookingStatus.workStarted,
        )
        .toList();
  }

  /// Active Bookings (per specification: accepted, confirmed, on_the_way, arrived, work_started)
  List<Booking> get activeBookings {
    return _bookings
        .where(
          (b) =>
              b.status == BookingStatus.accepted ||
              b.status == BookingStatus.confirmed ||
              b.status == BookingStatus.onTheWay ||
              b.status == BookingStatus.arrived ||
              b.status == BookingStatus.workStarted,
        )
        .toList();
  }

  /// 4. Completed Jobs
  List<Booking> get completedBookings {
    return _bookings.where((b) => b.status == BookingStatus.completed).toList();
  }

  /// 5. History Jobs (Completed, Declined, Cancelled, Expired)
  List<Booking> get historyJobs {
    return _bookings.where((b) => b.status.isHistory).toList();
  }

  /// Single Current Ongoing Job (if any)
  Booking? get currentActiveJob {
    final confirmed = confirmedJobs;
    if (confirmed.isNotEmpty) return confirmed.first;
    final accepted = acceptedJobs;
    return accepted.isNotEmpty ? accepted.first : null;
  }

  // Counts for Dashboard Overview
  int get pendingRequestsCount =>
      incomingRequests.length + (_isDemoMode ? _serviceRequests.length : 0);
  int get acceptedJobsCount => acceptedJobs.length;
  int get confirmedJobsCount => confirmedJobs.length;
  int get activeBookingsCount => activeBookings.length;
  int get completedJobsCount => completedBookings.length;

  // Verified Digital Earnings - Strictly excludes Cash payments
  double get totalEarnings {
    if (!_isDemoMode && _earningsSummary.totalDigitalEarnings > 0) {
      return _earningsSummary.totalDigitalEarnings;
    }
    return _transactions
        .where(
          (t) =>
              t.paymentStatus == PaymentStatus.paid &&
              t.paymentMethod.isDigital,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // ============================
  // Session Check & Initialization
  // ============================

  Future<void> checkSession() async {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('is_demo_session') == true) {
          await loginWithDemo();
        }
      } catch (_) {}
      return;
    }

    final authUser = SupabaseService.currentUser;
    if (authUser != null) {
      final metadata = authUser.userMetadata ?? {};
      final fullName = metadata['full_name']?.toString() ??
          metadata['name']?.toString() ??
          'Partner';
      final phone = authUser.phone ?? metadata['phone']?.toString() ?? '';
      final email = authUser.email ?? metadata['email']?.toString() ?? '';
      final avatarUrl = metadata['avatar_url']?.toString() ??
          metadata['picture']?.toString();

      // Immediately mark as logged in with non-null agent profile so Home renders instantly without blank shimmers
      _isLoggedIn = true;
      _isDemoMode = false;
      _isNewUser = false;
      _agent = AgentProfile(
        id: _providerId ?? '',
        userId: authUser.id,
        fullName: fullName.isNotEmpty ? fullName : 'Partner',
        phone: phone,
        services: const [],
        serviceArea: 'Amritsar, Punjab',
        isOnline: true,
      );
      notifyListeners();

      try {
        await _loadSupabaseUserData(
          userId: authUser.id,
          phone: phone,
          email: email,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );
      } catch (e) {
        debugPrint('[AppState] checkSession background load notice: $e');
      } finally {
        _setLoading(false);
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('is_demo_session') == true) {
          await loginWithDemo();
        }
      } catch (_) {}
      _setLoading(false);
    }
  }

  // ============================
  // Authentication (Email & Password)
  // ============================

  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
      try {
        final res = await _authRepo.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user ?? _authRepo.currentAuthUser;
        if (user != null) {
          final metadata = user.userMetadata ?? {};
          final fullName =
              metadata['full_name']?.toString() ??
              metadata['name']?.toString() ??
              '';
          final avatarUrl =
              metadata['avatar_url']?.toString() ??
              metadata['picture']?.toString();
          final userEmail = user.email ?? email;

          await _loadSupabaseUserData(
            userId: user.id,
            phone: user.phone ?? '',
            email: userEmail,
            fullName: fullName,
            avatarUrl: avatarUrl,
          );
          _isLoggedIn = true;
          _isDemoMode = false;
          _setLoading(false);
          return true;
        } else {
          _error = 'Sign-in succeeded but no active session was returned.';
          _setLoading(false);
          return false;
        }
      } catch (e) {
        if (e is AppAuthException) {
          _error = e.message;
        } else {
          _error = 'Sign-in failed: ${e.toString()}';
        }
        _setLoading(false);
        return false;
      }
    } else {
      // Demo / simulated login when Supabase is unconfigured
      await Future.delayed(const Duration(milliseconds: 600));
      _isNewUser = false;
      _isDemoMode = true;
      _isLoggedIn = true;
      _agent = MockDataService.demoAgent;
      _serviceRequests = List.from(MockDataService.demoRequests);
      _bookings = List.from(MockDataService.demoBookings);
      _transactions = List.from(MockDataService.demoTransactions);
      _chatMessages = List.from(MockDataService.demoMessages);
      _setLoading(false);
      return true;
    }
  }

  /// Registers with email and password.
  /// Returns a map: {'success': bool, 'needsEmailConfirmation': bool}
  Future<Map<String, bool>> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _setLoading(true);
    _error = null;

    if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
      try {
        final res = await _authRepo.signUp(
          email: email,
          password: password,
          fullName: fullName,
        );

        final user = res.user;
        final session = res.session;

        // If email confirmation is enabled in Supabase, session will be null
        if (session == null && user != null) {
          _isLoggedIn = false;
          _setLoading(false);
          return {'success': true, 'needsEmailConfirmation': true};
        }

        // If session is present immediately (e.g. auto-confirm enabled)
        if (user != null) {
          await _loadSupabaseUserData(
            userId: user.id,
            phone: '',
            email: email,
            fullName: fullName,
          );
          _isNewUser = true; // Guide new registrant through onboarding
          _isLoggedIn = true;
          _isDemoMode = false;
          _setLoading(false);
          return {'success': true, 'needsEmailConfirmation': false};
        }

        _error = 'Registration succeeded but no account was returned.';
        _setLoading(false);
        return {'success': false, 'needsEmailConfirmation': false};
      } catch (e) {
        if (e is AppAuthException) {
          _error = e.message;
        } else {
          _error = 'Registration failed: ${e.toString()}';
        }
        _setLoading(false);
        return {'success': false, 'needsEmailConfirmation': false};
      }
    } else {
      // Demo mode fallback registration
      await Future.delayed(const Duration(milliseconds: 600));
      _isNewUser = true;
      _isDemoMode = true;
      _isLoggedIn = true;
      _agent = AgentProfile(
        id: 'agent_new',
        fullName: fullName,
        phone: '',
        services: [],
      );
      _bookings = [];
      _serviceRequests = [];
      _transactions = [];
      _setLoading(false);
      return {'success': true, 'needsEmailConfirmation': false};
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _error = null;

    if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
      try {
        await _authRepo.resetPasswordForEmail(email);
        _setLoading(false);
        return true;
      } catch (e) {
        if (e is AppAuthException) {
          _error = e.message;
        } else {
          _error = 'Failed to send reset email: ${e.toString()}';
        }
        _setLoading(false);
        return false;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      _setLoading(false);
      return true;
    }
  }

  Future<void> loginWithDemo() async {
    _setLoading(true);
    _isDemoMode = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_demo_session', true);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 600));

    String? cachedAvatar;
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedAvatar =
          prefs.getString('cached_demo_avatar') ?? prefs.getString('cached_avatar');
    } catch (_) {}

    _agent = MockDataService.demoAgent.copyWith(
      profileImage: (cachedAvatar != null && cachedAvatar.isNotEmpty)
          ? cachedAvatar
          : MockDataService.demoAgent.profileImage,
    );
    _serviceRequests = List.from(MockDataService.demoRequests);
    _bookings = List.from(MockDataService.demoBookings);
    _transactions = List.from(MockDataService.demoTransactions);
    _chatMessages = List.from(MockDataService.demoMessages);
    _isLoggedIn = true;
    _isNewUser = false;
    _error = null;
    _setLoading(false);
  }

  Future<void> _loadSupabaseUserData({
    required String userId,
    String? phone,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_demo_session', false);
    } catch (_) {}

    // 1. Get or create public user record
    final publicUser = await _authRepo.getOrCreatePublicUser(
      userId: userId,
      phone: phone,
      email: email,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );

    // 2. Resolve provider record strictly using user_id = auth.uid()
    final partnerName = (publicUser.fullName?.isNotEmpty == true)
        ? publicUser.fullName!
        : (fullName?.isNotEmpty == true ? fullName! : 'Partner');

    ProviderModel? provider;
    try {
      provider = await _providerRepo.getProviderByUserId(userId);
    } catch (e) {
      debugPrint('[AppState] Provider profile query notice: $e');
    }

    // Resolve provider ID strictly from providers.id (never confuse with user_id)
    _providerId = provider?.id;

    // Auto-create/link provider record if not found so authenticated partner is never stuck
    if (_providerId == null) {
      try {
        provider = await _providerRepo.getOrCreateProviderProfile(
          userId: userId,
          businessName: partnerName,
        );
        _providerId = provider.id;
      } catch (e) {
        debugPrint('[AppState] getOrCreateProviderProfile notice: $e');
      }
    }

    // Authenticated partner is ready - never send them to onboarding
    _isNewUser = false;

    String? effectiveAvatar;
    if (publicUser.avatarUrl != null && publicUser.avatarUrl!.isNotEmpty) {
      effectiveAvatar = publicUser.avatarUrl;
    } else if (provider?.avatarUrl != null && provider!.avatarUrl!.isNotEmpty) {
      effectiveAvatar = provider.avatarUrl;
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      effectiveAvatar = avatarUrl;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (effectiveAvatar == null || effectiveAvatar.isEmpty) {
        effectiveAvatar =
            prefs.getString('cached_avatar_$userId') ??
            prefs.getString('cached_avatar');
      } else {
        await prefs.setString('cached_avatar_$userId', effectiveAvatar);
        await prefs.setString('cached_avatar', effectiveAvatar);
      }
    } catch (_) {}

    _agent = AgentProfile(
      id: _providerId ?? '',
      userId: userId,
      fullName: provider?.businessName ?? partnerName,
      phone: publicUser.phone ?? phone ?? '',
      profileImage: effectiveAvatar,
      services: [],
      serviceArea: provider?.city ?? provider?.address ?? 'Amritsar, Punjab',
      isOnline: provider?.isAvailable ?? true,
      description: provider?.description,
    );
    notifyListeners();

    // 3. Fetch provider services & bookings asynchronously in background without blocking app startup
    if (_providerId != null) {
      _setupRealtimeSubscription(_providerId!);

      _providerRepo
          .getProviderServices(_providerId!)
          .then((services) {
            final sNames = services.map((s) => s.name.toLowerCase()).toList();
            if (_agent != null && sNames.isNotEmpty) {
              _agent = _agent!.copyWith(services: sNames);
              notifyListeners();
            }
          })
          .catchError((_) {});

      refreshBookings().catchError((e) {
        debugPrint('[AppState] Initial booking refresh notice: $e');
      });
    }

    // Ensure incoming call listener is active for this agent's user UUID
    IncomingCallManager.instance.startListening();

    // Register FCM device push token with Supabase
    DeviceTokenRepository.instance.initAndRegister(userId);
  }

  Timer? _backgroundPollingTimer;

  void _startBackgroundPolling() {
    _backgroundPollingTimer?.cancel();
    _backgroundPollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_providerId != null && !_isRefreshingBookings && !_isDemoMode) {
        refreshBookings().catchError((_) {});
      }
    });
  }

  /// Realtime listener on bookings and messages for assigned provider
  void _setupRealtimeSubscription(String providerId) {
    try {
      _startBackgroundPolling();
      _bookingsChannel?.unsubscribe();
      _bookingsChannel = _bookingRepo.subscribeToProviderBookings(
        providerId: providerId,
        onUpdate: () {
          debugPrint('[AppState] Realtime booking update received!');
          refreshBookings();
        },
      );

      final currentUserId = SupabaseService.currentUser?.id ?? '';
      if (currentUserId.isNotEmpty) {
        _messagesChannel?.unsubscribe();
        _messagesChannel = _chatRepo.subscribeToAllMessages(
          currentUserId: currentUserId,
          onMessage: (model) {
            final convId = model.conversationId;
            if (_conversationIds.containsValue(convId)) {
              final matchingBooking = _bookings.firstWhere(
                (b) => _conversationIds[b.id] == convId,
                orElse: () => _bookings.first,
              );
              final chatMsg = ChatMessage.fromDbModel(
                model,
                bookingId: matchingBooking.id,
                defaultSenderName: model.isMe
                    ? (_agent?.fullName ?? 'You')
                    : 'Customer',
              );

              if (!_chatMessages.any((m) => m.id == chatMsg.id)) {
                _chatMessages.add(chatMsg);
                if (!chatMsg.isMe) {
                  for (final entry in _conversationIds.entries) {
                    if (entry.value == convId) {
                      _unreadCounts[entry.key] =
                          (_unreadCounts[entry.key] ?? 0) + 1;
                    }
                  }
                }
                notifyListeners();
              }
            } else {
              // Newly initiated customer conversation - auto synchronize
              refreshBookings();
            }
          },
          onUpdate: (record) {
            final msgId = record[MessageColumns.id]?.toString();
            final readAtStr = record[MessageColumns.readAt]?.toString();
            if (msgId != null && readAtStr != null) {
              final readAt = DateTime.tryParse(readAtStr);
              final idx = _chatMessages.indexWhere((m) => m.id == msgId);
              if (idx >= 0 && _chatMessages[idx].readAt == null) {
                _chatMessages[idx] = _chatMessages[idx].copyWith(
                  readAt: readAt,
                );
                notifyListeners();
              }
            }
          },
        );
      }
      // Start Realtime incoming call detection for this agent
      IncomingCallManager.instance.startListening();
    } catch (e) {
      debugPrint('[AppState] Realtime subscription notice: $e');
    }
  }

  bool _isRefreshingBookings = false;
  bool _needsRerefreshed = false;

  Future<void> refreshBookings() async {
    if (_isDemoMode) {
      _serviceRequests = List.from(MockDataService.demoRequests);
      _bookings = List.from(MockDataService.demoBookings);
      _transactions = List.from(MockDataService.demoTransactions);
      _chatMessages = List.from(MockDataService.demoMessages);
      notifyListeners();
      return;
    }

    if (_providerId == null) {
      try {
        _providerId = await _bookingRepo.resolveCurrentProviderId();
      } catch (e) {
        debugPrint('[AppState] resolveCurrentProviderId in refresh error: $e');
      }
      if (_providerId == null) return;
    }

    if (_bookingsChannel == null && _providerId != null) {
      _setupRealtimeSubscription(_providerId!);
    }

    if (_isRefreshingBookings) {
      _needsRerefreshed = true;
      return;
    }
    _isRefreshingBookings = true;

    try {
      do {
        _needsRerefreshed = false;
        final dbBookings = await _bookingRepo.getBookingsForProvider(
          _providerId!,
        );
        final newBookings = dbBookings
            .map((b) => _mapDbBookingToUi(b))
            .toList();

        // Preserve any booking currently being mutated in-flight to prevent stale overwrites
        if (_inFlightStatusUpdates.isNotEmpty) {
          for (final inFlightId in _inFlightStatusUpdates) {
            final existing = _bookings.where((b) => b.id == inFlightId);
            if (existing.isNotEmpty) {
              final newIdx = newBookings.indexWhere((b) => b.id == inFlightId);
              if (newIdx >= 0) {
                newBookings[newIdx] = existing.first;
              }
            }
          }
        }
        _bookings = newBookings;
        _earningsSummary = EarningsSummary.fromBookings(dbBookings);

        // Populate real transaction items
        _transactions = _earningsSummary.items.map((i) {
          return Transaction(
            id: 'txn_${i.bookingId}',
            bookingId: i.bookingId,
            agentId: _providerId,
            serviceName: i.serviceName,
            amount: i.amount,
            paymentStatus: i.paymentStatus.isPaid
                ? PaymentStatus.paid
                : PaymentStatus.pending,
            paymentMethod: i.paymentMethod.isCash
                ? PaymentMethod.cash
                : PaymentMethod.razorpay,
            createdAt: i.createdAt,
          );
        }).toList();

        // Immediately notify UI so newly fetched requests show up right away
        notifyListeners();

        // Safe synchronization of conversations and unread customer messages
        try {
          final bookingIds = _bookings.map((b) => b.id).toList();
          final conversations = await _chatRepo
              .fetchExistingProviderConversations(bookingIds, _providerId);

          // Map conversations to booking IDs and sibling bookings sharing the same customer
          for (final conv in conversations) {
            _conversationIds[conv.bookingId] = conv.id;
          }

          // Propagate conversation IDs to all sibling bookings of the same customer
          for (final b in _bookings) {
            if (!_conversationIds.containsKey(b.id)) {
              final existingConvId = findExistingConversationForCustomer(b);
              if (existingConvId != null) {
                _conversationIds[b.id] = existingConvId;
              }
            }
          }

          // Fetch unread customer messages across existing conversations
          final currentUserId = SupabaseService.currentUser?.id;
          final uniqueConvIds = _conversationIds.values.toSet().toList();
          if (currentUserId != null && uniqueConvIds.isNotEmpty) {
            final unreadByConv = await _chatRepo
                .fetchUnreadCustomerMessageCounts(
                  currentUserId: currentUserId,
                  conversationIds: uniqueConvIds,
                );

            _unreadCounts.clear();
            for (final entry in _conversationIds.entries) {
              int count = unreadByConv[entry.value] ?? 0;
              // If all local messages for this conversation are already read, ignore stale unread counts
              final convMessages = _chatMessages.where((m) =>
                  m.conversationId == entry.value || m.bookingId == entry.key);
              if (convMessages.isNotEmpty &&
                  convMessages.every((m) => m.isMe || m.readAt != null)) {
                count = 0;
              }
              if (count > 0) {
                _unreadCounts[entry.key] = count;
              }
            }

            // Preload messages for discovered conversations to populate ChatListScreen
            final dbMessages = await _chatRepo.fetchMessagesForConversations(
              uniqueConvIds,
              currentUserId: currentUserId,
            );
            if (dbMessages.isNotEmpty) {
              final mapped = dbMessages.map((m) {
                final matchingBooking = _bookings.firstWhere(
                  (b) => _conversationIds[b.id] == m.conversationId,
                  orElse: () => _bookings.first,
                );
                return ChatMessage.fromDbModel(
                  m,
                  bookingId: matchingBooking.id,
                  defaultSenderName: m.isMe
                      ? (_agent?.fullName ?? 'You')
                      : 'Customer',
                );
              }).toList();

              final mappedConvIds = uniqueConvIds.toSet();
              final mappedIds = mapped.map((m) => m.id).toSet();
              _chatMessages.removeWhere(
                (m) =>
                    (m.conversationId != null &&
                        mappedConvIds.contains(m.conversationId)) ||
                    mappedIds.contains(m.id),
              );
              _chatMessages.addAll(mapped);
            }
            notifyListeners();
          }
        } catch (chatError) {
          debugPrint(
            '[AppState] Conversation sync notice in refresh: $chatError',
          );
        }
      } while (_needsRerefreshed);
    } catch (e) {
      debugPrint('[AppState] Refresh error: $e');
      notifyListeners();
    } finally {
      _isRefreshingBookings = false;
    }
  }

  /// Fetch and refresh a single booking record by ID directly from Supabase.
  ///
  /// Updates in-memory booking cache and returns the updated Booking object.
  Future<Booking?> refreshBooking(String bookingId) async {
    if (_isDemoMode) {
      final matches = _bookings.where((b) => b.id == bookingId);
      return matches.isNotEmpty ? matches.first : null;
    }

    try {
      final dbBooking = await _bookingRepo.getBookingById(bookingId);
      final uiBooking = _mapDbBookingToUi(dbBooking);

      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index >= 0) {
        _bookings[index] = uiBooking;
      } else {
        _bookings.insert(0, uiBooking);
      }
      notifyListeners();
      return uiBooking;
    } catch (e) {
      debugPrint('[AppState] refreshBooking notice: $e');
      final matches = _bookings.where((b) => b.id == bookingId);
      return matches.isNotEmpty ? matches.first : null;
    }
  }

  Booking _mapDbBookingToUi(BookingModel b) => mapDbBookingToUiStatic(b);

  /// Public static mapper to convert Supabase BookingModel to in-app Booking domain model.
  static Booking mapDbBookingToUiStatic(BookingModel b) {
    BookingStatus status = BookingStatus.confirmed;
    if (b.status != null) {
      final s = b.status!.toLowerCase().replaceAll('_', '');
      if (s == 'pending' || s == 'pendingresponse') {
        status = BookingStatus.pendingResponse;
      } else if (s == 'accepted') {
        status = BookingStatus.accepted;
      } else if (s == 'confirmed') {
        status = BookingStatus.confirmed;
      } else if (s == 'ontheway') {
        status = BookingStatus.onTheWay;
      } else if (s == 'arrived') {
        status = BookingStatus.arrived;
      } else if (s == 'workstarted') {
        status = BookingStatus.workStarted;
      } else if (s == 'completed') {
        status = BookingStatus.completed;
      } else if (s == 'declined') {
        status = BookingStatus.declined;
      } else if (s == 'cancelled') {
        status = BookingStatus.cancelled;
      } else if (s == 'expired') {
        status = BookingStatus.expired;
      }
    }

    PaymentStatus pStatus = PaymentStatus.pending;
    if (b.paymentStatus != null) {
      try {
        pStatus = PaymentStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == b.paymentStatus!.toLowerCase(),
          orElse: () => PaymentStatus.pending,
        );
      } catch (_) {}
    }

    PaymentMethod pMethod = PaymentMethod.razorpay;
    if (b.paymentMethod != null) {
      try {
        pMethod = PaymentMethod.values.firstWhere(
          (m) => m.name.toLowerCase() == b.paymentMethod!.toLowerCase(),
          orElse: () => PaymentMethod.razorpay,
        );
      } catch (_) {}
    }

    final isConfirmedOrBeyond =
        status == BookingStatus.accepted ||
        status == BookingStatus.confirmed ||
        status == BookingStatus.onTheWay ||
        status == BookingStatus.arrived ||
        status == BookingStatus.workStarted ||
        status == BookingStatus.completed;

    final customerPhone = isConfirmedOrBeyond ? b.customer?.phone : null;
    final customerAddress = isConfirmedOrBeyond
        ? b.address
        : (b.address != null
              ? (b.address!.contains(',')
                    ? '${b.address!.split(',').first} (Area)'
                    : b.address)
              : 'Customer Area');

    final serviceType =
        b.service?.name.toLowerCase() ??
        (b.serviceId != null && b.serviceId!.isNotEmpty
            ? b.serviceId!
            : 'service');

    return Booking(
      id: b.id,
      customerId: b.customerId,
      customerName: b.customer?.fullName ?? 'Customer',
      customerPhone: customerPhone,
      serviceType: serviceType,
      description: b.notes ?? b.service?.description ?? 'Service request',
      appointmentTime: b.scheduledAt ?? b.createdAt ?? DateTime.now(),
      customerAddress: customerAddress,
      customerLatitude: b.customerLatitude,
      customerLongitude: b.customerLongitude,
      status: status,
      agreedPrice: b.price,
      paymentStatus: pStatus,
      paymentMethod: pMethod,
      createdAt: b.createdAt ?? DateTime.now(),
    );
  }

  Future<void> logout() async {
    _bookingsChannel?.unsubscribe();
    _bookingsChannel = null;
    _messagesChannel?.unsubscribe();
    _messagesChannel = null;

    for (final channel in _chatChannels.values) {
      channel.unsubscribe();
    }
    _chatChannels.clear();
    _conversationIds.clear();

    final currentUserId = SupabaseService.currentUser?.id ?? _agent?.userId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      await DeviceTokenRepository.instance.removeTokenOnLogout(currentUserId);
    }

    IncomingCallManager.instance.stopListening();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_demo_session', false);
    } catch (_) {}

    if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
      try {
        await _authRepo.signOut();
      } catch (_) {}
    }
    _isLoggedIn = false;
    _agent = null;
    _providerId = null;
    _bookings = [];
    _serviceRequests = [];
    _transactions = [];
    _chatMessages = [];
    _earningsSummary = EarningsSummary.empty();
    _isDemoMode = true;
    notifyListeners();
  }

  // ============================
  // Profile & Services
  // ============================

  Future<void> updateProfile(AgentProfile updatedProfile) async {
    _setLoading(true);
    final effectiveUserId = updatedProfile.userId ??
        _agent?.userId ??
        SupabaseService.currentUser?.id;

    String? effectiveProviderId = _providerId;
    if (effectiveProviderId == null && effectiveUserId != null && !_isDemoMode) {
      try {
        final prov = await _providerRepo.getProviderByUserId(effectiveUserId);
        effectiveProviderId = prov?.id;
        _providerId = effectiveProviderId;
      } catch (_) {}
    }

    if (!_isDemoMode && effectiveUserId != null) {
      try {
        await _profileRepo.updateUserProfile(
          userId: effectiveUserId,
          fullName: updatedProfile.fullName,
          phone: updatedProfile.phone,
        );

        if (effectiveProviderId != null) {
          await _providerRepo.updateProviderProfile(
            providerId: effectiveProviderId,
            businessName: updatedProfile.fullName,
            city: updatedProfile.serviceArea,
            address: updatedProfile.serviceArea,
            description: updatedProfile.description,
          );
        } else if (_isNewUser) {
          final newProvider = await _providerRepo.createProviderProfile(
            userId: effectiveUserId,
            businessName: updatedProfile.fullName,
            city: updatedProfile.serviceArea,
            address: updatedProfile.serviceArea,
            description: updatedProfile.description,
          );
          _providerId = newProvider.id;
          effectiveProviderId = newProvider.id;
        }

        if (updatedProfile.profileImage != null) {
          await _profileRepo.updateAvatarUrl(
            userId: effectiveUserId,
            providerId: effectiveProviderId,
            avatarUrl: updatedProfile.profileImage!,
          );
        }

        // Sync service mappings if available
        if (effectiveProviderId != null && updatedProfile.services.isNotEmpty) {
          final allServices = await _providerRepo.getAllServices();
          final matchingServiceIds = allServices
              .where(
                (s) => updatedProfile.services
                    .map((e) => e.toLowerCase())
                    .contains(s.name.toLowerCase()),
              )
              .map((s) => s.id)
              .toList();

          if (matchingServiceIds.isNotEmpty) {
            await _providerRepo.syncProviderServices(
              providerId: effectiveProviderId,
              serviceIds: matchingServiceIds,
            );
          }
        }
      } catch (e) {
        debugPrint('[AppState] Profile update exception: $e');
      }
    }

    if (updatedProfile.profileImage != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_isDemoMode) {
          await prefs.setString(
              'cached_demo_avatar', updatedProfile.profileImage!);
        } else if (effectiveUserId != null) {
          await prefs.setString(
              'cached_avatar_$effectiveUserId', updatedProfile.profileImage!);
        }
        await prefs.setString('cached_avatar', updatedProfile.profileImage!);
      } catch (_) {}
    }

    _agent = updatedProfile.copyWith(
      id: effectiveProviderId ?? updatedProfile.id,
      userId: effectiveUserId ?? updatedProfile.userId,
    );
    _isNewUser = false;
    _setLoading(false);
  }

  Future<void> updateProfileImage(String imageUrl) async {
    final effectiveUserId = _agent?.userId ?? SupabaseService.currentUser?.id;
    if (_agent == null && effectiveUserId == null) return;

    if (_agent != null) {
      _agent = _agent!.copyWith(
        userId: effectiveUserId ?? _agent!.userId,
        profileImage: imageUrl,
      );
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isDemoMode) {
        await prefs.setString('cached_demo_avatar', imageUrl);
      } else if (effectiveUserId != null) {
        await prefs.setString('cached_avatar_$effectiveUserId', imageUrl);
      }
      await prefs.setString('cached_avatar', imageUrl);
    } catch (_) {}

    if (!_isDemoMode && effectiveUserId != null) {
      try {
        await _profileRepo.updateAvatarUrl(
          userId: effectiveUserId,
          providerId: _providerId,
          avatarUrl: imageUrl,
        );
      } catch (e) {
        debugPrint('[AppState] updateProfileImage error: $e');
      }
    }
  }

  /// Uploads avatar image bytes to Supabase Storage and updates the profile image URL.
  Future<String?> uploadAvatarImage(
    Uint8List imageBytes,
    String fileExtension,
  ) async {
    final userId = _agent?.userId ?? SupabaseService.currentUser?.id;
    if (userId == null) return null;
    try {
      final publicUrl = await _profileRepo.uploadAvatar(
        userId: userId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );
      await updateProfileImage(publicUrl);
      return publicUrl;
    } catch (e) {
      debugPrint('[AppState] uploadAvatarImage error: $e');
      rethrow;
    }
  }

  Future<void> updateProviderServices(List<String> serviceNames) async {
    if (_agent == null) return;
    _agent = _agent!.copyWith(services: serviceNames);
    notifyListeners();

    if (!_isDemoMode && _providerId != null) {
      try {
        final allDbServices = await _providerRepo.getAllServices();
        final selectedIds = allDbServices
            .where((s) => serviceNames.contains(s.name.toLowerCase()))
            .map((s) => s.id)
            .toList();

        await _providerRepo.syncProviderServices(
          providerId: _providerId!,
          serviceIds: selectedIds,
        );
      } catch (e) {
        debugPrint('[AppState] Service sync exception: $e');
      }
    }
  }

  // ============================
  // Availability Status
  // ============================

  Future<void> toggleOnlineStatus() async {
    if (_agent == null) return;
    final newStatus = !_agent!.isOnline;
    _agent = _agent!.copyWith(isOnline: newStatus);
    notifyListeners();

    if (!_isDemoMode && _providerId != null) {
      try {
        await _providerRepo.updateAvailability(
          providerId: _providerId!,
          isAvailable: newStatus,
        );
      } catch (e) {
        debugPrint('[AppState] Availability update failed: $e');
      }
    }
  }

  // ============================
  // Request & Booking Lifecycle Actions
  // ============================

  /// Accept incoming service request (Changes status to 'accepted' awaiting ₹9 fee)
  Future<bool> acceptRequest(String requestId) async {
    _setLoading(true);
    _error = null;
    final cleanId = requestId.trim();
    try {
      if (!_isDemoMode) {
        if (cleanId.isEmpty) {
          throw const ValidationException(
            message: 'Booking request ID cannot be empty.',
            code: 'VALIDATION_ERROR',
          );
        }
        if (cleanId.startsWith('req_')) {
          throw const ValidationException(
            message:
                'Cannot accept mock request while connected to live Supabase.',
            code: 'INVALID_REQUEST_ID',
          );
        }
        final authoritative = await _bookingRepo.acceptBooking(cleanId);
        final uiBooking = _mapDbBookingToUi(authoritative);
        final bookingIndex = _bookings.indexWhere(
          (b) => b.id == cleanId || b.requestId == cleanId,
        );
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = uiBooking;
        } else {
          _bookings.insert(0, uiBooking);
        }

        // Link with existing customer conversation immediately so returning customer's chat is preserved
        final existingConvId = findExistingConversationForCustomer(uiBooking);
        if (existingConvId != null) {
          _conversationIds[uiBooking.id] = existingConvId;
          debugPrint(
            '[AppState] Linked accepted booking ${uiBooking.id} to existing conversation $existingConvId for customer ${uiBooking.customerName}',
          );
        }

        // Notify customer that the partner is available for their request
        if (authoritative.customerId != null && authoritative.customerId!.isNotEmpty) {
          unawaited(
            NotificationSenderService.instance.sendAvailabilityResponse(
              customerUserId: authoritative.customerId!,
              bookingId: authoritative.id,
              isAvailable: true,
              agentName: _agent?.fullName ?? 'Partner',
              serviceName: uiBooking.serviceType,
            ),
          );
        }

        unawaited(
          refreshBookings().catchError((e) {
            debugPrint('[AppState] refreshBookings after accept notice: $e');
          }),
        );
      } else {
        final bookingIndex = _bookings.indexWhere(
          (b) => b.id == cleanId || b.requestId == cleanId,
        );
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
            status: BookingStatus.accepted,
          );
        } else {
          final requestIndex = _serviceRequests.indexWhere(
            (r) => r.id == cleanId,
          );
          if (requestIndex >= 0) {
            final request = _serviceRequests[requestIndex];
            _serviceRequests.removeAt(requestIndex);

            final newBooking = Booking(
              id: 'book_${DateTime.now().millisecondsSinceEpoch}',
              requestId: request.id,
              customerId: request.customerId,
              customerName: request.customerName,
              customerPhone: '+91 98765 43210',
              customerAddress: request.approximateArea,
              agentId: _agent?.id,
              serviceType: request.serviceType,
              description: request.description,
              appointmentTime: DateTime.now().add(const Duration(hours: 2)),
              status: BookingStatus.accepted,
              createdAt: DateTime.now(),
            );

            _bookings.insert(0, newBooking);
          }
        }
      }
      return true;
    } catch (e) {
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = 'Failed to accept booking: ${e.toString()}';
      }
      debugPrint('[AppState] Accept request error: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Decline incoming service request
  Future<bool> declineRequest(String requestId) async {
    _setLoading(true);
    _error = null;
    final cleanId = requestId.trim();
    try {
      if (!_isDemoMode) {
        if (cleanId.isEmpty) {
          throw const ValidationException(
            message: 'Booking request ID cannot be empty.',
            code: 'VALIDATION_ERROR',
          );
        }
        if (cleanId.startsWith('req_')) {
          throw const ValidationException(
            message:
                'Cannot decline mock request while connected to live Supabase.',
            code: 'INVALID_REQUEST_ID',
          );
        }
        final authoritative = await _bookingRepo.declineBooking(cleanId);
        final uiBooking = _mapDbBookingToUi(authoritative);
        final bookingIndex = _bookings.indexWhere(
          (b) => b.id == cleanId || b.requestId == cleanId,
        );
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = uiBooking;
        } else {
          _bookings.insert(0, uiBooking);
        }
        // Notify customer that the partner is unavailable for their request
        if (authoritative.customerId != null && authoritative.customerId!.isNotEmpty) {
          unawaited(
            NotificationSenderService.instance.sendAvailabilityResponse(
              customerUserId: authoritative.customerId!,
              bookingId: authoritative.id,
              isAvailable: false,
              agentName: _agent?.fullName ?? 'Partner',
              serviceName: uiBooking.serviceType,
            ),
          );
        }

        unawaited(
          refreshBookings().catchError((e) {
            debugPrint('[AppState] refreshBookings after decline notice: $e');
          }),
        );
      } else {
        final bookingIndex = _bookings.indexWhere(
          (b) => b.id == cleanId || b.requestId == cleanId,
        );
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
            status: BookingStatus.declined,
          );
        } else {
          _serviceRequests.removeWhere((r) => r.id == cleanId);
        }
      }
      return true;
    } catch (e) {
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = 'Failed to decline booking: ${e.toString()}';
      }
      debugPrint('[AppState] Decline request error: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  String _mapUiStatusToDb(BookingStatus s) {
    switch (s) {
      case BookingStatus.pendingResponse:
        return DbBookingStatuses.pendingResponse;
      case BookingStatus.accepted:
        return DbBookingStatuses.accepted;
      case BookingStatus.confirmed:
        return DbBookingStatuses.confirmed;
      case BookingStatus.onTheWay:
        return DbBookingStatuses.onTheWay;
      case BookingStatus.arrived:
        return DbBookingStatuses.arrived;
      case BookingStatus.workStarted:
        return DbBookingStatuses.workStarted;
      case BookingStatus.completed:
        return DbBookingStatuses.completed;
      case BookingStatus.declined:
        return DbBookingStatuses.declined;
      case BookingStatus.cancelled:
        return DbBookingStatuses.cancelled;
      default:
        return DbBookingStatuses.confirmed;
    }
  }

  /// Update booking stage: 'on_the_way', 'arrived', 'work_started', 'completed'
  Future<bool> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    final cleanId = bookingId.trim();
    if (_inFlightStatusUpdates.contains(cleanId)) {
      debugPrint(
        '[AppState] Status update already in flight for $cleanId, dropping duplicate tap.',
      );
      return false;
    }

    _inFlightStatusUpdates.add(cleanId);
    _setLoading(true);
    _error = null;
    _statusInfoMessage = null;

    try {
      if (!_isDemoMode) {
        final existingBooking = _bookings.where((b) => b.id == cleanId);
        final previousStatus = existingBooking.isNotEmpty
            ? existingBooking.first.status
            : null;
        final String dbStatus = _mapUiStatusToDb(newStatus);

        final wasAlreadyAtTarget =
            previousStatus != null &&
            DbBookingStatuses.hasReachedOrPassed(
              _mapUiStatusToDb(previousStatus),
              dbStatus,
            );

        // Authoritative update via repository (which pre-checks Supabase & handles conflicts)
        final authoritativeModel = await _bookingRepo.updateBookingStatus(
          bookingId: cleanId,
          status: dbStatus,
        );

        // Immediately map and update in-memory cache with authoritative record
        final uiBooking = _mapDbBookingToUi(authoritativeModel);
        final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = uiBooking;
        } else {
          _bookings.insert(0, uiBooking);
        }

        // Only show duplicate/progressed info message if the target was ALREADY reached before this update call
        if (wasAlreadyAtTarget) {
          final authoritativeDbStatus = authoritativeModel.status
              ?.toLowerCase()
              .trim();
          final requestedDbStatus = dbStatus.toLowerCase().trim();
          if (authoritativeDbStatus != null) {
            final authOrder = DbBookingStatuses.lifecycleOrder(
              authoritativeDbStatus,
            );
            final reqOrder = DbBookingStatuses.lifecycleOrder(
              requestedDbStatus,
            );
            if (authOrder > reqOrder) {
              _statusInfoMessage =
                  'Booking has already progressed to ${uiBooking.status.label}.';
            } else {
              _statusInfoMessage =
                  'Booking status is already updated to ${uiBooking.status.label}.';
            }
          }
        }

        // Notify customer when partner arrives at location
        if (newStatus == BookingStatus.arrived &&
            authoritativeModel.customerId != null &&
            authoritativeModel.customerId!.isNotEmpty) {
          unawaited(
            NotificationSenderService.instance.sendArrivalNotification(
              customerUserId: authoritativeModel.customerId!,
              bookingId: authoritativeModel.id,
              agentName: _agent?.fullName ?? 'Partner',
            ),
          );
        }

        // Safely refresh background collections without throwing or failing this status change
        unawaited(
          refreshBookings().catchError((e) {
            debugPrint('[AppState] Background refreshBookings notice: $e');
          }),
        );
      } else {
        final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
        if (bookingIndex >= 0) {
          _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
            status: newStatus,
          );
        }
      }

      // Automatically manage live GPS broadcasting for Customer tracking
      if (newStatus == BookingStatus.onTheWay) {
        AgentLocationPublisher().startBroadcasting();
      } else if (newStatus == BookingStatus.arrived ||
          newStatus == BookingStatus.completed ||
          newStatus == BookingStatus.cancelled) {
        AgentLocationPublisher().stopBroadcasting();
      }

      return true;
    } catch (e) {
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = 'Failed to update job status: ${e.toString()}';
      }
      debugPrint('[AppState] updateBookingStatus error: $e');
      if (!_isDemoMode) {
        try {
          await refreshBooking(cleanId);
        } catch (_) {}
      }
      return false;
    } finally {
      _inFlightStatusUpdates.remove(cleanId);
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Update agreed price for a service job
  Future<bool> setBookingPrice(String bookingId, double price) async {
    final cleanId = bookingId.trim();
    try {
      if (!_isDemoMode) {
        await _bookingRepo.updateBookingPrice(bookingId: cleanId, price: price);
      }

      final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
      if (bookingIndex >= 0) {
        _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
          agreedPrice: price,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[AppState] setBookingPrice error: $e');
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = 'Failed to update agreed price: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }

  /// Set payment method on completion
  Future<bool> setBookingPaymentMethod(
    String bookingId,
    PaymentMethod method,
  ) async {
    final cleanId = bookingId.trim();
    try {
      if (!_isDemoMode) {
        await _paymentRepo.setBookingPaymentMethod(
          bookingId: cleanId,
          method: method == PaymentMethod.cash
              ? AppPaymentMethod.cash
              : AppPaymentMethod.razorpay,
        );
      }

      final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
      if (bookingIndex >= 0) {
        _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
          paymentMethod: method,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[AppState] Payment method update error: $e');
      return false;
    }
  }

  /// Confirm cash payment received from customer for ₹amount
  Future<bool> confirmCashPayment(String bookingId, double amount) async {
    final cleanId = bookingId.trim();
    try {
      if (!_isDemoMode) {
        await _paymentRepo.confirmCashPaymentReceived(
          bookingId: cleanId,
          amount: amount,
        );
      }
      final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
      if (bookingIndex >= 0) {
        _bookings[bookingIndex] = _bookings[bookingIndex].copyWith(
          agreedPrice: amount,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.paid,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[AppState] confirmCashPayment error: $e');
      _error = 'Failed to record cash payment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Request customer to pay ₹amount via UPI/Razorpay
  Future<bool> requestUpiPayment(String bookingId, double amount) async {
    final cleanId = bookingId.trim();
    try {
      if (!_isDemoMode) {
        await _paymentRepo.requestUpiPayment(
          bookingId: cleanId,
          amount: amount,
        );
      }
      final bookingIndex = _bookings.indexWhere((b) => b.id == cleanId);
      if (bookingIndex >= 0) {
        final currentBooking = _bookings[bookingIndex];
        _bookings[bookingIndex] = currentBooking.copyWith(
          agreedPrice: amount,
          paymentMethod: PaymentMethod.razorpay,
          paymentStatus: PaymentStatus.pending,
        );
        notifyListeners();

        // Notify customer that service payment is requested
        if (currentBooking.customerId != null && currentBooking.customerId!.isNotEmpty) {
          unawaited(
            NotificationSenderService.instance.sendUpiPaymentRequestNotification(
              customerUserId: currentBooking.customerId!,
              bookingId: cleanId,
              amount: amount,
              agentName: _agent?.fullName ?? 'Partner',
            ),
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint('[AppState] requestUpiPayment error: $e');
      _error = 'Failed to request UPI payment: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Development/Testing helper: simulate customer platform fee confirmation via backend RPC
  Future<bool> simulateCustomerConfirmation(String bookingId) async {
    _setLoading(true);
    _error = null;
    try {
      if (_isDemoMode) {
        final bookingIndex = _bookings.indexWhere((b) => b.id == bookingId);
        if (bookingIndex >= 0) {
          final existing = _bookings[bookingIndex];
          _bookings[bookingIndex] = existing.copyWith(
            status: BookingStatus.confirmed,
            paymentStatus: PaymentStatus.paid,
          );
        }
        return true;
      }

      // 1. Call trusted backend RPC
      await _bookingRepo.simulateConfirmBooking(bookingId);

      // 2. Fetch fresh state from Supabase to verify persistence
      final refreshed = await refreshBooking(bookingId);
      if (refreshed == null || refreshed.status != BookingStatus.confirmed) {
        throw const DatabaseException(
          message:
              'Booking confirmation failed on backend. Ensure "simulate_confirm_booking" RPC is active in Supabase.',
        );
      }

      return true;
    } catch (e) {
      if (e is AppException) {
        _error = e.message;
      } else {
        _error = 'Failed to simulate confirmation: ${e.toString()}';
      }
      debugPrint('[AppState] simulateCustomerConfirmation error: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============================
  // Chat Messaging (Customer-Unified)
  // ============================

  /// Check if a booking is in an eligible lifecycle state for live chat.
  /// (Must be confirmed, on_the_way, arrived, or work_started).
  bool isChatEligible(Booking booking) {
    return booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.onTheWay ||
        booking.status == BookingStatus.arrived ||
        booking.status == BookingStatus.workStarted;
  }

  /// Determines if two bookings belong to the same customer (by UUID, phone, or name).
  bool isSameCustomer(Booking a, Booking b) {
    if (a.id == b.id) return true;
    if (a.customerId != null &&
        a.customerId!.isNotEmpty &&
        b.customerId != null &&
        b.customerId!.isNotEmpty) {
      return a.customerId == b.customerId;
    }
    if (a.customerPhone != null &&
        a.customerPhone!.isNotEmpty &&
        b.customerPhone != null &&
        b.customerPhone!.isNotEmpty) {
      return a.customerPhone == b.customerPhone;
    }
    final nameA = a.customerName.trim().toLowerCase();
    final nameB = b.customerName.trim().toLowerCase();
    if (nameA.isNotEmpty &&
        nameB.isNotEmpty &&
        nameA != 'customer' &&
        nameA == nameB) {
      return true;
    }
    return false;
  }

  /// Generates a unique, stable customer key to group all bookings with the same customer.
  String getCustomerKey(Booking b) {
    if (b.customerId != null && b.customerId!.isNotEmpty) {
      return 'cust_${b.customerId}';
    }
    if (b.customerPhone != null && b.customerPhone!.isNotEmpty) {
      return 'phone_${b.customerPhone}';
    }
    final name = b.customerName.trim().toLowerCase();
    if (name.isNotEmpty && name != 'customer') {
      return 'name_$name';
    }
    return 'booking_${b.id}';
  }

  /// Check if any existing conversation ID is already registered for this customer in memory.
  String? findExistingConversationForCustomer(Booking target) {
    if (_conversationIds.containsKey(target.id)) {
      return _conversationIds[target.id];
    }
    for (final b in _bookings) {
      if (isSameCustomer(b, target)) {
        final convId = _conversationIds[b.id];
        if (convId != null && convId.isNotEmpty) {
          _conversationIds[target.id] = convId;
          return convId;
        }
      }
    }
    return null;
  }

  /// Total unread messages across all bookings for this customer.
  int getUnreadCountForCustomer(Booking booking) {
    int count = 0;
    final seenConversations = <String>{};
    final seenBookings = <String>{};
    for (final b in _bookings) {
      if (isSameCustomer(b, booking)) {
        final convId = _conversationIds[b.id];
        if (convId != null && convId.isNotEmpty) {
          // Prevent double-counting sibling bookings that share the same unified conversation
          if (!seenConversations.contains(convId)) {
            seenConversations.add(convId);
            count += _unreadCounts[b.id] ?? 0;
          }
        } else {
          if (!seenBookings.contains(b.id)) {
            seenBookings.add(b.id);
            count += _unreadCounts[b.id] ?? 0;
          }
        }
      }
    }
    return count;
  }

  /// Get cached messages for a booking or its unified conversation with this customer.
  List<ChatMessage> getMessagesForBooking(String bookingId) {
    final booking = _bookings.where((b) => b.id == bookingId).firstOrNull;
    var convId = _conversationIds[bookingId];
    if (convId == null && booking != null) {
      convId = findExistingConversationForCustomer(booking);
    }

    final Set<String> relatedBookingIds = {bookingId};
    if (booking != null) {
      for (final b in _bookings) {
        if (isSameCustomer(b, booking)) {
          relatedBookingIds.add(b.id);
        }
      }
    }

    return _chatMessages.where((m) {
      if (convId != null && m.conversationId != null) {
        return m.conversationId == convId;
      }
      return relatedBookingIds.contains(m.bookingId);
    }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Strictly fetch existing conversation ID for a booking in Supabase without creating one.
  ///
  /// Supports unified conversations shared across multiple bookings for the same customer.
  /// CRITICAL: The Agent app must never create conversations.
  Future<String?> getExistingConversationForBooking(String bookingId) async {
    if (_isDemoMode) {
      return 'demo_conv_$bookingId';
    }

    if (_conversationIds.containsKey(bookingId)) {
      return _conversationIds[bookingId];
    }

    // 1. Sibling booking check: if another booking with the same customer already has a conversation ID
    final booking = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (booking != null) {
      final existingConv = findExistingConversationForCustomer(booking);
      if (existingConv != null) {
        _conversationIds[bookingId] = existingConv;
        return existingConv;
      }
    }

    // 2. Query ChatRepository for existing conversation or sibling booking conversation
    try {
      final customerId = booking?.customerId;
      final conv = await _chatRepo.getExistingConversation(
        bookingId,
        customerId: customerId,
        providerId: _providerId,
      );
      if (conv != null) {
        _conversationIds[bookingId] = conv.id;
        // Map all sibling bookings for this customer to the unified conversation
        if (booking != null) {
          for (final b in _bookings.where((b) => isSameCustomer(b, booking))) {
            _conversationIds[b.id] = conv.id;
          }
        }
        return conv.id;
      }
      return null;
    } catch (e) {
      debugPrint('[AppState] getExistingConversation error: $e');
      return null;
    }
  }

  /// Compatibility alias: Never creates conversations from Agent app.
  Future<String?> getOrCreateConversationForBooking(String bookingId) async {
    return getExistingConversationForBooking(bookingId);
  }

  /// Load and synchronize messages from Supabase for a booking.
  Future<List<ChatMessage>> loadMessagesForBooking(String bookingId) async {
    if (_isDemoMode) {
      return getMessagesForBooking(bookingId);
    }

    try {
      final convId = await getExistingConversationForBooking(bookingId);
      if (convId == null) {
        // Conversation has not been initiated by customer yet
        return getMessagesForBooking(bookingId);
      }

      final currentUserId =
          SupabaseConfig.isConfigured && SupabaseService.isInitialized
          ? SupabaseService.client.auth.currentUser?.id
          : null;

      final dbMessages = await _chatRepo.getMessages(
        convId,
        currentUserId: currentUserId,
      );

      final mapped = dbMessages.map((m) {
        return ChatMessage.fromDbModel(
          m,
          bookingId: bookingId,
          defaultSenderName: m.isMe ? (_agent?.fullName ?? 'You') : 'Customer',
        );
      }).toList();

      // Replace cached messages for this conversation and booking
      final mappedIds = mapped.map((m) => m.id).toSet();
      _chatMessages.removeWhere(
        (m) =>
            m.conversationId == convId ||
            m.bookingId == bookingId ||
            mappedIds.contains(m.id),
      );
      _chatMessages.addAll(mapped);

      // Attempt read receipts update safely
      if (currentUserId != null) {
        await _chatRepo.markMessagesAsRead(
          conversationId: convId,
          currentUserId: currentUserId,
        );
      }

      // Immediately zero out unread counts for this conversation and all associated bookings
      _unreadCounts[bookingId] = 0;
      final currentBooking = _bookings.where((b) => b.id == bookingId).firstOrNull;
      if (currentBooking != null) {
        for (final b in _bookings.where((b) => isSameCustomer(b, currentBooking))) {
          _unreadCounts[b.id] = 0;
        }
      }
      for (final entry in _conversationIds.entries) {
        if (entry.value == convId) {
          _unreadCounts[entry.key] = 0;
        }
      }

      // Mark in-memory messages as read
      final now = DateTime.now();
      for (int i = 0; i < _chatMessages.length; i++) {
        final m = _chatMessages[i];
        if ((m.conversationId == convId || m.bookingId == bookingId) &&
            !m.isMe &&
            m.readAt == null) {
          _chatMessages[i] = m.copyWith(readAt: now);
        }
      }

      notifyListeners();
      return getMessagesForBooking(bookingId);
    } catch (e) {
      debugPrint('[AppState] loadMessagesForBooking error: $e');
      return getMessagesForBooking(bookingId);
    }
  }

  /// Mark incoming customer messages as read and clear unread indicator.
  Future<void> markIncomingMessagesRead(String bookingId) async {
    final now = DateTime.now();

    // 1. Immediately clear in-memory unread counts for this booking and all sibling bookings
    final booking = _bookings.where((b) => b.id == bookingId).firstOrNull;
    if (booking != null) {
      for (final b in _bookings.where((b) => isSameCustomer(b, booking))) {
        _unreadCounts[b.id] = 0;
      }
    }
    _unreadCounts[bookingId] = 0;

    // 2. Mark local in-memory messages as read
    for (int i = 0; i < _chatMessages.length; i++) {
      final m = _chatMessages[i];
      if ((m.bookingId == bookingId ||
              (booking != null &&
                  _bookings.any((b) => b.id == m.bookingId && isSameCustomer(b, booking)))) &&
          !m.isMe &&
          m.readAt == null) {
        _chatMessages[i] = m.copyWith(readAt: now);
      }
    }

    // 3. Resolve conversation ID and clear all entries matching convId
    final convId = await getExistingConversationForBooking(bookingId);
    if (convId != null) {
      for (final entry in _conversationIds.entries) {
        if (entry.value == convId) {
          _unreadCounts[entry.key] = 0;
        }
      }
      for (int i = 0; i < _chatMessages.length; i++) {
        final m = _chatMessages[i];
        if (m.conversationId == convId && !m.isMe && m.readAt == null) {
          _chatMessages[i] = m.copyWith(readAt: now);
        }
      }
    }
    notifyListeners();

    // 4. Persist read receipts to database
    if (convId != null) {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != null) {
        await _chatRepo.markMessagesAsRead(
          conversationId: convId,
          currentUserId: currentUserId,
        );
      }
    }
  }

  /// Simulate an incoming unread customer message for testing or demo purposes.
  void simulateIncomingCustomerMessage({
    required String bookingId,
    required String message,
    String? conversationId,
  }) {
    final newMsg = ChatMessage(
      id: 'msg_test_${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      conversationId: conversationId ?? _conversationIds[bookingId] ?? 'conv_$bookingId',
      senderId: 'customer_sim',
      senderName: 'Customer',
      message: message,
      createdAt: DateTime.now(),
      readAt: null,
      isMe: false,
    );
    _chatMessages.add(newMsg);
    _unreadCounts[bookingId] = (_unreadCounts[bookingId] ?? 0) + 1;
    notifyListeners();
  }

  /// Send message in booking conversation.
  Future<bool> sendMessage(String bookingId, String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;

    if (_isDemoMode) {
      final newMessage = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        bookingId: bookingId,
        senderId: _agent?.id ?? 'agent_001',
        senderName: _agent?.fullName ?? 'Agent',
        message: trimmed,
        createdAt: DateTime.now(),
        isMe: true,
      );
      _chatMessages.add(newMessage);
      notifyListeners();

      Future.delayed(const Duration(seconds: 2), () {
        final reply = ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_reply',
          bookingId: bookingId,
          senderId: 'cust_target',
          senderName: 'Customer',
          message: _getDemoReply(),
          createdAt: DateTime.now(),
          isMe: false,
        );
        _chatMessages.add(reply);
        _unreadCounts[bookingId] = (_unreadCounts[bookingId] ?? 0) + 1;
        notifyListeners();
      });
      return true;
    }

    try {
      final currentUserId = SupabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) {
        _error = 'You must be signed in to send messages.';
        notifyListeners();
        return false;
      }

      final convId = await getExistingConversationForBooking(bookingId);
      if (convId == null) {
        _error = 'Customer has not initiated chat for this booking yet.';
        notifyListeners();
        return false;
      }

      final dbMessage = await _chatRepo.sendMessage(
        conversationId: convId,
        senderId: currentUserId,
        content: trimmed,
      );

      final chatMessage = ChatMessage.fromDbModel(
        dbMessage,
        bookingId: bookingId,
        defaultSenderName: _agent?.fullName ?? 'You',
      );

      if (!_chatMessages.any((m) => m.id == chatMessage.id)) {
        _chatMessages.add(chatMessage);
        notifyListeners();
      }

      // Notify customer of new chat message
      final targetBooking = _bookings.where((b) => b.id == bookingId).firstOrNull;
      if (targetBooking?.customerId != null && targetBooking!.customerId!.isNotEmpty) {
        unawaited(
          NotificationSenderService.instance.sendChatMessageNotification(
            recipientUserId: targetBooking.customerId!,
            senderName: _agent?.fullName ?? 'Partner',
            content: trimmed,
            bookingId: bookingId,
            conversationId: convId,
          ),
        );
      }

      return true;
    } on AppException catch (appErr) {
      _error = appErr.message;
      debugPrint('[AppState] Send message app error: ${appErr.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send message: ${e.toString()}';
      debugPrint('[AppState] Send message error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to real-time chat messages for a specific booking.
  Future<sp.RealtimeChannel?> subscribeToBookingChat(
    String bookingId, {
    required void Function(ChatMessage message) onMessageReceived,
  }) async {
    if (_isDemoMode) return null;

    final convId = await getExistingConversationForBooking(bookingId);
    if (convId == null) {
      // Customer has not created a conversation yet
      return null;
    }

    if (_chatChannels.containsKey(bookingId)) {
      return _chatChannels[bookingId];
    }

    final currentUserId = SupabaseService.client.auth.currentUser?.id ?? '';
    final channel = _chatRepo.subscribeToConversationMessages(
      conversationId: convId,
      currentUserId: currentUserId,
      onMessageReceived: (model) {
        final chatMsg = ChatMessage.fromDbModel(
          model,
          bookingId: bookingId,
          defaultSenderName: model.isMe
              ? (_agent?.fullName ?? 'You')
              : 'Customer',
        );

        if (!_chatMessages.any((m) => m.id == chatMsg.id)) {
          _chatMessages.add(chatMsg);
          if (!chatMsg.isMe) {
            for (final entry in _conversationIds.entries) {
              if (entry.value == convId) {
                _unreadCounts[entry.key] = (_unreadCounts[entry.key] ?? 0) + 1;
              }
            }
          }
          notifyListeners();
          onMessageReceived(chatMsg);
        }
      },
    );

    if (channel != null) {
      _chatChannels[bookingId] = channel;
    }
    return channel;
  }

  /// Unsubscribe and cleanup real-time channel for a booking chat.
  void unsubscribeFromBookingChat(String bookingId) {
    if (_chatChannels.containsKey(bookingId)) {
      final channel = _chatChannels.remove(bookingId);
      if (channel != null) {
        if (SupabaseConfig.isConfigured && SupabaseService.isInitialized) {
          try {
            SupabaseService.client.removeChannel(channel);
          } catch (_) {
            channel.unsubscribe();
          }
        } else {
          channel.unsubscribe();
        }
      }
    }
  }

  String _getDemoReply() {
    final replies = [
      'Okay, thanks for the update!',
      'Great, I will be waiting.',
      'How long will the work take approximately?',
      'Please let me know when you reach nearby.',
      'Sure, no problem.',
    ];
    return replies[DateTime.now().millisecond % replies.length];
  }

  // ============================
  // Helper Methods
  // ============================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _backgroundPollingTimer?.cancel();
    _bookingsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }
}
