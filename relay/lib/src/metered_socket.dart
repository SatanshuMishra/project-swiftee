import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _longestHeader = 14;
const _finalFrame = 0x80;
const _opcodeBits = 0x0f;
const _maskedFrame = 0x80;
const _lengthBits = 0x7f;
const _continuation = 0;
const _firstNonDataOpcode = 3;
const _ping = 9;

enum Breach {
  tooBig('too-big', destroys: false),
  unfinished('unfinished', destroys: true),
  byteRate('byte-rate', destroys: true),
  pings('pings', destroys: true);

  const Breach(this.reason, {required this.destroys});

  final String reason;
  final bool destroys;
}

final class MeteredSocket extends Stream<Uint8List> implements Socket {
  MeteredSocket(
    this._socket, {
    required int maxMessageBytes,
    required int bytesPerSecond,
    required int pingsPerSecond,
    required this._breached,
  }) : _meter = _FrameMeter(
         maxMessageBytes: maxMessageBytes,
         bytesPerSecond: bytesPerSecond,
         pingsPerSecond: pingsPerSecond,
       );

  final Socket _socket;
  final _FrameMeter _meter;
  final void Function(Breach breach) _breached;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _socket.listen(
    (chunk) => _admit(chunk, onData),
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  void _admit(Uint8List chunk, void Function(Uint8List event)? onData) {
    final (:admitted, :breach) = _meter.measure(chunk);
    if (admitted > 0 && onData != null) {
      onData(
        admitted == chunk.length
            ? chunk
            : Uint8List.sublistView(chunk, 0, admitted),
      );
    }
    if (breach == null) return;
    if (breach.destroys) _socket.destroy();
    _breached(breach);
  }

  @override
  Encoding get encoding => _socket.encoding;

  @override
  set encoding(Encoding value) => _socket.encoding = value;

  @override
  void write(Object? object) => _socket.write(object);

  @override
  void writeln([Object? object = '']) => _socket.writeln(object);

  @override
  void writeCharCode(int charCode) => _socket.writeCharCode(charCode);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _socket.writeAll(objects, separator);

  @override
  void add(List<int> data) => _socket.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) =>
      _socket.addStream(stream);

  @override
  Future<dynamic> flush() => _socket.flush();

  @override
  Future<dynamic> close() => _socket.close();

  @override
  Future<dynamic> get done => _socket.done;

  @override
  void destroy() => _socket.destroy();

  @override
  int get port => _socket.port;

  @override
  int get remotePort => _socket.remotePort;

  @override
  InternetAddress get address => _socket.address;

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
}

final class _FrameMeter {
  _FrameMeter({
    required int maxMessageBytes,
    required int bytesPerSecond,
    required int pingsPerSecond,
  }) : _maxMessageBytes = maxMessageBytes,
       _maxUnfinishedBytes = 2 * maxMessageBytes,
       _bytesPerSecond = bytesPerSecond.toDouble(),
       _allowance = bytesPerSecond.toDouble(),
       _pingsPerSecond = pingsPerSecond.toDouble(),
       _pingAllowance = pingsPerSecond.toDouble();

  final int _maxMessageBytes;
  final int _maxUnfinishedBytes;
  final double _bytesPerSecond;
  final _clock = Stopwatch()..start();
  final _header = Uint8List(_longestHeader);
  final double _pingsPerSecond;
  double _allowance;
  double _pingAllowance;
  var _refilledAt = 0;
  var _pingsRefilledAt = 0;
  var _headerBytes = 0;
  var _payloadLeft = 0;
  var _messageBytes = 0;
  var _unfinishedBytes = 0;
  var _endsMessage = false;
  var _refusing = false;
  var _dead = false;

  ({int admitted, Breach? breach}) measure(Uint8List chunk) {
    if (_dead) return (admitted: 0, breach: null);
    if (!_spend(chunk.length)) return _die(Breach.byteRate);
    if (_refusing) return (admitted: 0, breach: null);
    var frameStart = 0;
    var index = 0;
    while (index < chunk.length) {
      if (_payloadLeft > 0) {
        final step = min(_payloadLeft, chunk.length - index);
        _payloadLeft -= step;
        _unfinishedBytes += step;
        index += step;
        if (_payloadLeft == 0) _endFrame();
      } else {
        if (_headerBytes == 0) frameStart = index;
        _header[_headerBytes++] = chunk[index++];
        _unfinishedBytes++;
        if (_headerBytes == _headerLength) {
          switch (_startFrame()) {
            case Breach.tooBig:
              _refusing = true;
              return (admitted: frameStart, breach: Breach.tooBig);
            case final Breach breach:
              return _die(breach);
            case null:
              break;
          }
        }
      }
      if (_unfinishedBytes > _maxUnfinishedBytes) {
        return _die(Breach.unfinished);
      }
    }
    return (admitted: chunk.length, breach: null);
  }

  int get _headerLength {
    if (_headerBytes < 2) return 2;
    final extended = switch (_header[1] & _lengthBits) {
      126 => 2,
      127 => 8,
      _ => 0,
    };
    final mask = (_header[1] & _maskedFrame) != 0 ? 4 : 0;
    return 2 + extended + mask;
  }

  int get _payloadLength => switch (_header[1] & _lengthBits) {
    126 => (_header[2] << 8) | _header[3],
    127 =>
      _header.sublist(2, 10).fold(0, (length, byte) => (length << 8) | byte),
    final length => length,
  };

  Breach? _startFrame() {
    final opcode = _header[0] & _opcodeBits;
    final length = _payloadLength;
    final carriesData = opcode < _firstNonDataOpcode;
    _headerBytes = 0;
    _endsMessage = carriesData && (_header[0] & _finalFrame) != 0;
    if (length < 0 || length > _maxMessageBytes) return Breach.tooBig;
    if (opcode == _ping && !_spendPing()) return Breach.pings;
    if (carriesData) {
      _messageBytes = (opcode == _continuation ? _messageBytes : 0) + length;
      if (_messageBytes > _maxMessageBytes) return Breach.tooBig;
    }
    _payloadLeft = length;
    if (length == 0) _endFrame();
    return null;
  }

  bool _spendPing() {
    final now = _clock.elapsedMicroseconds;
    final refill =
        (now - _pingsRefilledAt) *
        _pingsPerSecond /
        Duration.microsecondsPerSecond;
    _pingAllowance = min(_pingsPerSecond, _pingAllowance + refill) - 1;
    _pingsRefilledAt = now;
    return _pingAllowance >= 0;
  }

  void _endFrame() {
    if (!_endsMessage) return;
    _messageBytes = 0;
    _unfinishedBytes = 0;
  }

  bool _spend(int bytes) {
    final now = _clock.elapsedMicroseconds;
    final refill =
        (now - _refilledAt) * _bytesPerSecond / Duration.microsecondsPerSecond;
    _allowance = min(_bytesPerSecond, _allowance + refill) - bytes;
    _refilledAt = now;
    return _allowance >= 0;
  }

  ({int admitted, Breach? breach}) _die(Breach breach) {
    _dead = true;
    return (admitted: 0, breach: breach);
  }
}
