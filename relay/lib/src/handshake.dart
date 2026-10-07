import 'dart:convert';

import 'package:crypto/crypto.dart';

const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

final _webSocketKey = RegExp(r'^[A-Za-z0-9+/]{22}==$');

bool isWebSocketKey(String key) => _webSocketKey.hasMatch(key);

String webSocketAccept(String key) =>
    base64.encode(sha1.convert(ascii.encode('$key$_webSocketGuid')).bytes);
