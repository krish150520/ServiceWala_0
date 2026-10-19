import 'dart:async';

/// Network connectivity status
enum NetworkStatus { online, offline }

/// Simple connectivity check service
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;

  NetworkStatus get status => _status;
  Stream<NetworkStatus> get statusStream => _controller.stream;

  void updateStatus(NetworkStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _controller.add(newStatus);
    }
  }

  void dispose() {
    _controller.close();
  }
}
