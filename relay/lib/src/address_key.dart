import 'dart:io';
import 'dart:typed_data';

String addressKey(InternetAddress address) {
  final raw = address.rawAddress;
  return switch (address.type) {
    InternetAddressType.IPv6 when _mapsIPv4(raw) => raw.skip(12).join('.'),
    InternetAddressType.IPv6 => '${_network(raw)}::/64',
    _ => address.address,
  };
}

bool _mapsIPv4(Uint8List raw) =>
    raw.length == 16 &&
    raw.take(10).every((byte) => byte == 0) &&
    raw[10] == 0xff &&
    raw[11] == 0xff;

String _network(Uint8List raw) => [
  for (var i = 0; i < 8; i += 2) ((raw[i] << 8) | raw[i + 1]).toRadixString(16),
].join(':');
