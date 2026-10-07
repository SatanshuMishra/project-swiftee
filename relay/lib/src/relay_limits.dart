import 'package:together_protocol/together_protocol.dart' as protocol;

final class RelayLimits {
  const RelayLimits({
    this.maxSockets = 200,
    this.maxSocketsPerAddress = 16,
    this.maxRooms = 50,
    this.maxRoomsPerAddress = 2,
    this.roomIdleTimeout = const Duration(hours: 2),
    this.maxMessageBytes = protocol.maxMessageBytes,
    this.inboundBytesPerSecond = 4 * protocol.maxMessageBytes,
    this.pingsPerSecond = 4,
    this.maxQueuedBytes = 256 * 1024,
    this.burstMessages = 60,
    this.messageWindow = const Duration(seconds: 1),
    this.handshakeTimeout = const Duration(seconds: 10),
    this.closeGrace = const Duration(seconds: 5),
    this.httpIdleTimeout = const Duration(seconds: 15),
    this.authFailures = 10,
    this.authWindow = const Duration(minutes: 10),
    this.joinRefusalsPerSocket = 3,
    this.joinRefusalsPerAddress = 20,
    this.joinRefusalWindow = const Duration(minutes: 10),
    this.maxTrackedAddresses = 4096,
    this.pingInterval = const Duration(seconds: 20),
  });

  final int maxSockets;
  final int maxSocketsPerAddress;
  final int maxRooms;
  final int maxRoomsPerAddress;
  final Duration roomIdleTimeout;
  final int maxMessageBytes;
  final int inboundBytesPerSecond;
  final int pingsPerSecond;
  final int maxQueuedBytes;
  final int burstMessages;
  final Duration messageWindow;
  final Duration handshakeTimeout;
  final Duration closeGrace;
  final Duration httpIdleTimeout;
  final int authFailures;
  final Duration authWindow;
  final int joinRefusalsPerSocket;
  final int joinRefusalsPerAddress;
  final Duration joinRefusalWindow;
  final int maxTrackedAddresses;
  final Duration pingInterval;
}
