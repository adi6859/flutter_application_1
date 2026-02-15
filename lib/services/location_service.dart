import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:h3_flutter/h3_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationUpdate {
  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.h3Cell,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? h3Cell;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'h3Cell': h3Cell,
    };
  }

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      h3Cell: json['h3Cell'] as String?,
    );
  }
}

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  static const int _h3Resolution = 10;
  static const Duration _minDwellDuration = Duration(minutes: 2);
  static const Duration _heartbeatSendInterval = Duration(minutes: 20);

  static const String _historyStorageKey = 'presence_history_v1';
  static const int _maxHistoryEntries = 250;

  static const double _drivingSpeedThresholdMps = 8.0;
  static const double _drivingDistanceFilterMeters = 500.0;
  static const double _normalDistanceFilterMeters = 150.0;

  static final Uri _presenceApiUri = Uri.parse(
    'https://example.com/api/presence',
  );
  static final bool _debugLogsEnabled = kDebugMode;

  final H3 _h3 = const H3Factory().load();

  final StreamController<LocationUpdate> _locationController =
      StreamController<LocationUpdate>.broadcast();
  final StreamController<List<LocationUpdate>> _historyController =
      StreamController<List<LocationUpdate>>.broadcast();

  bool _isInitialized = false;
  bool _isTracking = false;
  bool _listenersRegistered = false;
  bool _historyLoaded = false;
  Future<void>? _initializeFuture;

  String? _currentCell;
  DateTime? _cellEnterTime;
  DateTime? _lastSentTime;
  String? _lastSentCell;
  bool _isDriving = false;

  final List<LocationUpdate> _history = <LocationUpdate>[];

  Stream<LocationUpdate> get locationStream => _locationController.stream;
  Stream<List<LocationUpdate>> get historyStream => _historyController.stream;
  List<LocationUpdate> get historySnapshot =>
      List<LocationUpdate>.unmodifiable(_history);

  List<LocationUpdate> getHistoryForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _history
        .where((item) {
          final timestamp = item.timestamp;
          return !timestamp.isBefore(dayStart) && timestamp.isBefore(dayEnd);
        })
        .toList(growable: false);
  }

  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    try {
      await _loadHistoryFromStorage();

      if (!_listenersRegistered) {
        bg.BackgroundGeolocation.onLocation(_onLocation, (
          bg.LocationError error,
        ) {
          debugPrint('[onLocation] ERROR: ${error.code}, ${error.message}');
        });
        bg.BackgroundGeolocation.onMotionChange(_onMotionChange);
        bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
        bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);
        _listenersRegistered = true;
      }

      await bg.BackgroundGeolocation.ready(
        bg.Config(
          desiredAccuracy: bg.Config.DESIRED_ACCURACY_MEDIUM,
          distanceFilter: _normalDistanceFilterMeters,
          stopTimeout: 3,
          activityRecognitionInterval: 10000,
          heartbeatInterval: 1200,
          disableElasticity: false,
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          foregroundService: true,
          pausesLocationUpdatesAutomatically: true,
          activityType: bg.Config.ACTIVITY_TYPE_OTHER,
          locationUpdateInterval: 60000,
          fastestLocationUpdateInterval: 30000,
          debug: _debugLogsEnabled,
          logLevel: _debugLogsEnabled
              ? bg.Config.LOG_LEVEL_VERBOSE
              : bg.Config.LOG_LEVEL_OFF,
        ),
      );

      _isInitialized = true;
    } catch (error, stackTrace) {
      _initializeFuture = null;
      _log('LocationService.initialize failed: $error', stackTrace);
      rethrow;
    }
  }

  Future<void> startTracking() async {
    try {
      await initialize();
      final state = await bg.BackgroundGeolocation.state;
      if (!state.enabled) {
        await bg.BackgroundGeolocation.start();
      }
      _isTracking = true;
    } catch (error, stackTrace) {
      _log('LocationService.startTracking failed: $error', stackTrace);
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    try {
      final state = await bg.BackgroundGeolocation.state;
      if (state.enabled) {
        await bg.BackgroundGeolocation.stop();
      }
      _isTracking = false;
    } catch (error, stackTrace) {
      _log('LocationService.stopTracking failed: $error', stackTrace);
      rethrow;
    }
  }

  void _onLocation(bg.Location location) {
    final latitude = location.coords.latitude;
    final longitude = location.coords.longitude;
    final speed = location.coords.speed.toDouble();
    final now = DateTime.now();

    _emitUiLocation(latitude, longitude);

    if (_isDriving) return;
    if (speed > _drivingSpeedThresholdMps) return;

    final newCellIndex = _h3.geoToCell(
      GeoCoord(lat: latitude, lon: longitude),
      _h3Resolution,
    );
    final newCell = newCellIndex.toString();

    if (_currentCell == null) {
      _currentCell = newCell;
      _cellEnterTime = now;
      return;
    }

    if (newCell != _currentCell) {
      _currentCell = newCell;
      _cellEnterTime = now;
      return;
    }

    final enterTime = _cellEnterTime!;
    final dwellDuration = now.difference(enterTime);
    if (dwellDuration < _minDwellDuration) return;

    final isUnsyncedCell = _lastSentCell != _currentCell;
    final heartbeatDue = _isHeartbeatDue(now);

    if (isUnsyncedCell || heartbeatDue) {
      unawaited(_sendAndMark(latitude: latitude, longitude: longitude));
    }
  }

  void _onMotionChange(bg.Location location) {
    if (location.isMoving || _isDriving) return;

    final latitude = location.coords.latitude;
    final longitude = location.coords.longitude;
    _emitUiLocation(latitude, longitude);
    unawaited(_sendAndMark(latitude: latitude, longitude: longitude));
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    final bool nowDriving =
        event.activity == 'in_vehicle' && event.confidence > 70;

    if (nowDriving == _isDriving) return;
    _isDriving = nowDriving;

    unawaited(_applyMotionAdaptiveConfig());
  }

  Future<void> _applyMotionAdaptiveConfig() async {
    try {
      final config = _isDriving
          ? bg.Config(
              distanceFilter: _drivingDistanceFilterMeters,
              desiredAccuracy: bg.Config.DESIRED_ACCURACY_LOW,
            )
          : bg.Config(
              distanceFilter: _normalDistanceFilterMeters,
              desiredAccuracy: bg.Config.DESIRED_ACCURACY_MEDIUM,
            );

      await bg.BackgroundGeolocation.setConfig(config);
    } catch (error, stackTrace) {
      _log('setConfig during activity change failed: $error', stackTrace);
    }
  }

  void _onHeartbeat(bg.HeartbeatEvent event) {
    if (_isDriving || !_isTracking) return;

    final now = DateTime.now();
    if (!_isHeartbeatDue(now)) return;

    unawaited(_sendHeartbeatFromCurrentPosition());
  }

  Future<void> _sendHeartbeatFromCurrentPosition() async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1,
        persist: false,
      );

      await _sendAndMark(
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      );
    } catch (error, stackTrace) {
      _log('getCurrentPosition/send heartbeat failed: $error', stackTrace);
    }
  }

  bool _isHeartbeatDue(DateTime now) {
    if (_lastSentTime == null) return true;
    return now.difference(_lastSentTime!) >= _heartbeatSendInterval;
  }

  Future<void> _sendAndMark({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final sentAt = DateTime.now();
      await _sendPresenceToServer(latitude: latitude, longitude: longitude);
      _lastSentTime = sentAt;
      _lastSentCell = _currentCell;

      await _addHistory(
        LocationUpdate(
          latitude: latitude,
          longitude: longitude,
          timestamp: sentAt,
          h3Cell: _currentCell,
        ),
      );
    } catch (error, stackTrace) {
      _log('Presence send failed: $error', stackTrace);
    }
  }

  Future<void> _sendPresenceToServer({
    required double latitude,
    required double longitude,
  }) async {
    final payload = <String, dynamic>{
      'lat': latitude,
      'lng': longitude,
      'h3_res': _h3Resolution,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await http.post(
      _presenceApiUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Presence API failed [${response.statusCode}]: ${response.body}',
      );
    }
  }

  void _emitUiLocation(double latitude, double longitude) {
    if (_locationController.isClosed) return;
    _locationController.add(
      LocationUpdate(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        h3Cell: _currentCell,
      ),
    );
  }

  Future<void> _loadHistoryFromStorage() async {
    if (_historyLoaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_historyStorageKey);

      if (jsonString == null || jsonString.isEmpty) {
        _historyLoaded = true;
        _emitHistory();
        return;
      }

      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final loadedHistory = decoded.map((dynamic item) {
        final map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
        return LocationUpdate.fromJson(map);
      }).toList();

      _history
        ..clear()
        ..addAll(loadedHistory.take(_maxHistoryEntries));

      if (_history.isNotEmpty) {
        _lastSentTime = _history.last.timestamp;
        _lastSentCell = _history.last.h3Cell;
      }

      _historyLoaded = true;
      _emitHistory();
    } catch (error, stackTrace) {
      _historyLoaded = true;
      _log('Loading history failed: $error', stackTrace);
      _emitHistory();
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _history.map((LocationUpdate item) => item.toJson()).toList(),
      );
      await prefs.setString(_historyStorageKey, encoded);
    } catch (error, stackTrace) {
      _log('Persisting history failed: $error', stackTrace);
    }
  }

  void _emitHistory() {
    if (_historyController.isClosed) return;
    _historyController.add(List<LocationUpdate>.unmodifiable(_history));
  }

  Future<void> _addHistory(LocationUpdate update) async {
    _history.add(update);
    if (_history.length > _maxHistoryEntries) {
      _history.removeAt(0);
    }

    _emitHistory();
    await _persistHistory();
  }

  Future<void> dispose() async {
    bg.BackgroundGeolocation.removeListeners();
    await _locationController.close();
    await _historyController.close();
  }

  void _log(String message, [StackTrace? stackTrace]) {
    if (!_debugLogsEnabled) return;
    debugPrint(message);
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
