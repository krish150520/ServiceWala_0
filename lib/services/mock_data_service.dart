import 'package:service_wala_business/config/constants.dart';
import 'package:service_wala_business/models/agent_profile.dart';
import 'package:service_wala_business/models/booking.dart';
import 'package:service_wala_business/models/chat_message.dart';
import 'package:service_wala_business/models/service_request.dart';
import 'package:service_wala_business/models/transaction.dart';

/// Provides realistic demo data for the app when backend is unavailable.
/// All data is clearly identified as sample data.
class MockDataService {
  static final AgentProfile demoAgent = AgentProfile(
    id: 'agent_001',
    userId: 'user_001',
    fullName: 'Rahul Sharma',
    phone: '+91 98765 43210',
    services: ['electrician', 'ac_repair', 'appliance_repair'],
    serviceArea: 'Koramangala, Bangalore',
    latitude: 12.9352,
    longitude: 77.6245,
    isOnline: true,
    verificationStatus: 'verified',
    yearsExperience: 5,
    description: 'Experienced electrician and AC technician with 5 years of experience in residential and commercial services.',
    createdAt: DateTime.now().subtract(const Duration(days: 180)),
  );

  static final List<ServiceRequest> demoRequests = [
    ServiceRequest(
      id: 'req_001',
      customerId: 'cust_001',
      customerName: 'Priya M.',
      serviceType: 'electrician',
      description: 'Need to fix a faulty MCB that keeps tripping. The kitchen circuit goes off every few hours.',
      preferredTime: 'Today, 2:00 PM - 4:00 PM',
      approximateArea: 'HSR Layout, Sector 2',
      latitude: 12.9116,
      longitude: 77.6389,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    ServiceRequest(
      id: 'req_002',
      customerId: 'cust_002',
      customerName: 'Amit K.',
      serviceType: 'ac_repair',
      description: 'Split AC not cooling properly. Makes a rattling noise when turned on. 1.5 ton LG unit.',
      preferredTime: 'Tomorrow, 10:00 AM - 12:00 PM',
      approximateArea: 'Indiranagar, 12th Main',
      latitude: 12.9784,
      longitude: 77.6408,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    ServiceRequest(
      id: 'req_003',
      customerId: 'cust_003',
      customerName: 'Sneha R.',
      serviceType: 'electrician',
      description: 'Need new electrical points installed in the bedroom. Two 5-amp sockets and one 15-amp socket.',
      preferredTime: 'Oct 11, 9:00 AM - 11:00 AM',
      approximateArea: 'Jayanagar, 4th Block',
      latitude: 12.9250,
      longitude: 77.5838,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  static final List<Booking> demoBookings = [
    // Active confirmed booking
    Booking(
      id: 'book_001',
      requestId: 'req_old_001',
      customerId: 'cust_010',
      customerName: 'Vikram Patel',
      agentId: 'agent_001',
      serviceType: 'electrician',
      description: 'Ceiling fan not working in the living room. Needs repair or replacement.',
      appointmentTime: DateTime.now().add(const Duration(hours: 2)),
      customerAddress: '42, 3rd Cross, Koramangala 5th Block, Bangalore - 560095',
      customerPhone: '+91 87654 32100',
      customerLatitude: 12.9340,
      customerLongitude: 77.6200,
      status: BookingStatus.confirmed,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    // Pending acceptance by customer
    Booking(
      id: 'book_002',
      requestId: 'req_old_002',
      customerId: 'cust_011',
      customerName: 'Meera S.',
      agentId: 'agent_001',
      serviceType: 'ac_repair',
      description: 'AC gas refill needed. Samsung 1 ton window AC.',
      appointmentTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
      status: BookingStatus.accepted,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    // Completed jobs
    Booking(
      id: 'book_003',
      requestId: 'req_old_003',
      customerId: 'cust_012',
      customerName: 'Ananya Reddy',
      agentId: 'agent_001',
      serviceType: 'electrician',
      description: 'Wiring issue in the kitchen. Short circuit in the switchboard.',
      appointmentTime: DateTime.now().subtract(const Duration(days: 2)),
      customerAddress: '15, MG Road, Bangalore',
      customerPhone: '+91 99887 76655',
      customerLatitude: 12.9756,
      customerLongitude: 77.6066,
      status: BookingStatus.completed,
      agreedPrice: 850,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Booking(
      id: 'book_004',
      requestId: 'req_old_004',
      customerId: 'cust_013',
      customerName: 'Raj Kumar',
      agentId: 'agent_001',
      serviceType: 'ac_repair',
      description: 'AC servicing and cleaning - 2 units',
      appointmentTime: DateTime.now().subtract(const Duration(days: 5)),
      customerAddress: '88, 1st Floor, BTM Layout, Bangalore',
      customerPhone: '+91 88776 65544',
      customerLatitude: 12.9166,
      customerLongitude: 77.6101,
      status: BookingStatus.completed,
      agreedPrice: 1200,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    Booking(
      id: 'book_005',
      requestId: 'req_old_005',
      customerId: 'cust_014',
      customerName: 'Sunita Devi',
      agentId: 'agent_001',
      serviceType: 'electrician',
      description: 'Install new ceiling fan and LED tube lights',
      appointmentTime: DateTime.now().subtract(const Duration(days: 8)),
      customerAddress: '22, Whitefield Main Road, Bangalore',
      customerPhone: '+91 77665 54433',
      customerLatitude: 12.9698,
      customerLongitude: 77.7500,
      status: BookingStatus.completed,
      agreedPrice: 1500,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
    Booking(
      id: 'book_006',
      requestId: 'req_old_006',
      customerId: 'cust_015',
      customerName: 'Karthik M.',
      agentId: 'agent_001',
      serviceType: 'appliance_repair',
      description: 'Washing machine not draining properly',
      appointmentTime: DateTime.now().subtract(const Duration(days: 12)),
      customerAddress: '10, JP Nagar 6th Phase, Bangalore',
      customerPhone: '+91 66554 43322',
      customerLatitude: 12.8900,
      customerLongitude: 77.5850,
      status: BookingStatus.completed,
      agreedPrice: 600,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 13)),
    ),
  ];

  static final List<Transaction> demoTransactions = [
    Transaction(
      id: 'txn_001',
      bookingId: 'book_003',
      agentId: 'agent_001',
      serviceName: 'Electrician - Wiring Repair',
      amount: 850,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: PaymentMethod.razorpay,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Transaction(
      id: 'txn_002',
      bookingId: 'book_004',
      agentId: 'agent_001',
      serviceName: 'AC Servicing - 2 Units',
      amount: 1200,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: PaymentMethod.razorpay,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Transaction(
      id: 'txn_003',
      bookingId: 'book_005',
      agentId: 'agent_001',
      serviceName: 'Fan & Light Installation',
      amount: 1500,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: PaymentMethod.cash, // Cash payment - excluded from digital earnings
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
    Transaction(
      id: 'txn_004',
      bookingId: 'book_006',
      agentId: 'agent_001',
      serviceName: 'Washing Machine Repair',
      amount: 600,
      paymentStatus: PaymentStatus.paid,
      paymentMethod: PaymentMethod.razorpay,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  static final List<ChatMessage> demoMessages = [
    ChatMessage(
      id: 'msg_001',
      bookingId: 'book_001',
      senderId: 'cust_010',
      senderName: 'Vikram Patel',
      message: 'Hi, the fan is in the living room. It stopped working suddenly yesterday.',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      isMe: false,
    ),
    ChatMessage(
      id: 'msg_002',
      bookingId: 'book_001',
      senderId: 'agent_001',
      senderName: 'Rahul Sharma',
      message: 'Understood. I will check the capacitor and winding. I will be there at the scheduled time.',
      createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 50)),
      isMe: true,
    ),
    ChatMessage(
      id: 'msg_003',
      bookingId: 'book_001',
      senderId: 'cust_010',
      senderName: 'Vikram Patel',
      message: 'Great, thank you! The building has a security gate, I will inform them about your visit.',
      createdAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 45)),
      isMe: false,
    ),
    ChatMessage(
      id: 'msg_004',
      bookingId: 'book_002',
      senderId: 'cust_011',
      senderName: 'Priya Sharma',
      message: 'Hello, please bring gas refill kit for the AC unit.',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      isMe: false,
    ),
    ChatMessage(
      id: 'msg_005',
      bookingId: 'book_002',
      senderId: 'agent_001',
      senderName: 'Rahul Sharma',
      message: 'Sure ma\'am, I have standard R32 and R410A kits ready.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 30)),
      isMe: true,
    ),
    ChatMessage(
      id: 'msg_006',
      bookingId: 'book_003',
      senderId: 'cust_012',
      senderName: 'Amit Verma',
      message: 'Thanks for the quick wiring fix! Everything is working properly.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      isMe: false,
    ),
  ];

  static double get totalEarnings {
    return demoTransactions
        .where((t) => t.paymentStatus == PaymentStatus.paid && t.paymentMethod.isDigital)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static int get completedJobsCount {
    return demoBookings
        .where((b) => b.status == BookingStatus.completed)
        .length;
  }
}
