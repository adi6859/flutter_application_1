class LocationUpdate {
  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.h3Cell,
    this.activity,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? h3Cell;
  final String? activity;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'h3Cell': h3Cell,
      'activity': activity,
      'accuracyMeters': accuracyMeters,
    };
  }

  factory LocationUpdate.fromJson(Map<String, dynamic> json) {
    return LocationUpdate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      h3Cell: json['h3Cell'] as String?,
      activity: json['activity'] as String?,
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
    );
  }
}
