/// Centralized Supabase Database Table & Column Constants.
///
/// Ensures exact matching with existing PostgreSQL schema shared between Customer (CX)
/// and Agent apps.
class DbTables {
  static const String users = 'users';
  static const String providers = 'providers';
  static const String services = 'services';
  static const String providerServices = 'provider_services';
  static const String bookings = 'bookings';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String calls = 'calls';
  static const String deviceTokens = 'device_tokens';
  static const String userFcmTokens = 'user_fcm_tokens';
}

/// Column names for the 'user_fcm_tokens' table
class UserFcmTokenColumns {
  static const String id = 'id';
  static const String userId = 'user_id';
  static const String fcmToken = 'fcm_token';
  static const String token = 'token';
  static const String platform = 'platform';
  static const String deviceInfo = 'device_info';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

/// Column names for the 'device_tokens' table
class DeviceTokenColumns {
  static const String id = 'id';
  static const String userId = 'user_id';
  static const String token = 'token';
  static const String platform = 'platform';
  static const String deviceInfo = 'device_info';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

/// Column names for the 'conversations' table
class ConversationColumns {
  static const String id = 'id';
  static const String bookingId = 'booking_id';
  static const String createdAt = 'created_at';
}

/// Column names for the 'messages' table
class MessageColumns {
  static const String id = 'id';
  static const String conversationId = 'conversation_id';
  static const String senderId = 'sender_id';
  static const String content = 'content';
  static const String createdAt = 'created_at';
  static const String readAt = 'read_at';
}

/// Column names for the 'users' table
class UserColumns {
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String fullName = 'full_name';
  static const String phone = 'phone';
  static const String role = 'role';
  static const String avatarUrl = 'avatar_url';
}

/// Column names for the 'providers' table
/// NOTE: 'desciption' is the exact column name in the PostgreSQL database.
class ProviderColumns {
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String userId = 'user_id';
  static const String businessName = 'business_name';
  static const String description = 'desciption'; // Exact database column name
  static const String address = 'address';
  static const String city = 'city';
  static const String isAvailable = 'is_available';
  static const String avatarUrl = 'avatar_url';
}

/// Column names for the 'services' table
class ServiceColumns {
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String name = 'name';
  static const String description = 'description';
  static const String icon = 'icon';
  static const String isActive = 'is_active';
}

/// Column names for the 'provider_services' table
class ProviderServiceColumns {
  static const String providerId = 'provider_id';
  static const String serviceId = 'services_id';
}

/// Column names for the 'bookings' table
class BookingColumns {
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String customerId = 'customer_id';
  static const String providerId = 'provider_id';
  static const String serviceId = 'service_id';
  static const String status = 'status';
  static const String address = 'address';
  static const String scheduledAt = 'scheduled_at';
  static const String notes = 'notes';
  static const String price = 'price';
  static const String paymentMethod = 'payment_method';
  static const String paymentStatus = 'payment_status';
}

/// Canonical payment methods stored in 'bookings.payment_method'
class DbPaymentMethods {
  static const String razorpay = 'razorpay';
  static const String online = 'online';
  static const String cash = 'cash';

  /// Check if the payment method string corresponds to an online digital payment
  static bool isOnline(String? method) {
    if (method == null) return false;
    final normalized = method.trim().toLowerCase();
    return normalized == razorpay || normalized == online;
  }

  /// Check if the payment method string is cash
  static bool isCash(String? method) {
    if (method == null) return false;
    return method.trim().toLowerCase() == cash;
  }
}

/// Canonical payment status values stored in 'bookings.payment_status'
class DbPaymentStatuses {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String failed = 'failed';
  static const String refunded = 'refunded';

  /// Check if the payment status indicates a successful paid settlement
  static bool isPaid(String? status) {
    if (status == null) return false;
    return status.trim().toLowerCase() == paid;
  }
}

/// Canonical booking status values stored in 'bookings.status'
class DbBookingStatuses {
  static const String pendingResponse = 'pending_response';
  static const String accepted = 'accepted';
  static const String confirmed = 'confirmed';
  static const String onTheWay = 'on_the_way';
  static const String arrived = 'arrived';
  static const String workStarted = 'work_started';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String declined = 'declined';

  /// Check if the booking status is completed
  static bool isCompleted(String? status) {
    if (status == null) return false;
    return status.trim().toLowerCase() == completed;
  }

  /// Canonical lifecycle progression order for active bookings.
  /// Higher index means a later stage in the lifecycle.
  static int lifecycleOrder(String? status) {
    if (status == null) return -1;
    final normalized = status.trim().toLowerCase();
    switch (normalized) {
      case pendingResponse:
        return 0;
      case accepted:
        return 1;
      case confirmed:
        return 2;
      case onTheWay:
        return 3;
      case arrived:
        return 4;
      case workStarted:
        return 5;
      case completed:
        return 6;
      case cancelled:
      case declined:
        return -1; // Terminal non-progressing states
      default:
        return -1;
    }
  }

  /// Returns true if the booking's current status has already reached or passed
  /// the target status in the linear progression.
  static bool hasReachedOrPassed(String? currentStatus, String targetStatus) {
    if (currentStatus == null) return false;
    final currentNorm = currentStatus.trim().toLowerCase();
    final targetNorm = targetStatus.trim().toLowerCase();
    if (currentNorm == targetNorm) return true;

    final currentOrder = lifecycleOrder(currentNorm);
    final targetOrder = lifecycleOrder(targetNorm);

    // If both are in the linear progression, compare order
    if (currentOrder >= 0 && targetOrder >= 0) {
      return currentOrder >= targetOrder;
    }
    return false;
  }
}
