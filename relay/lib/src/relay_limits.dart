import 'package:together_protocol/together_protocol.dart' as protocol;

final class RelayLimits {
  const RelayLimits({
    this.maxSockets = 200,
    this.maxSocketsPerAddress = 16,
    this.maxRooms = 50,
    this.maxMessageBytes = protocol.maxMessageBytes,
    this.burstMessages = 60,
    this.messageWindow = const Duration(seconds: 1),
    this.handshakeTimeout = const Duration(seconds: 10),
    this.authFailures = 10,
    this.authWindow = const Duration(minutes: 10),
    this.pingInterval = const Duration(seconds: 20),
  });

  final int maxSockets;
  final int maxSocketsPerAddress;
  final int maxRooms;
  final int maxMessageBytes;
  final int burstMessages;
  final Duration messageWindow;
  final Duration handshakeTimeout;
  final int authFailures;
  final Duration authWindow;
  final Duration pingInterval;
}
