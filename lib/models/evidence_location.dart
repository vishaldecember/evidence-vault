class EvidenceLocation {
  const EvidenceLocation({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
      };

  factory EvidenceLocation.fromJson(Map<String, dynamic> json) {
    return EvidenceLocation(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
    );
  }
}
