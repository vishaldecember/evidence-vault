class EvidenceDevice {
  const EvidenceDevice({
    required this.name,
    required this.platform,
    this.manufacturer,
    this.model,
  });

  /// Concise user-facing source: manufacturer + model when known.
  final String name;
  final String platform;
  final String? manufacturer;
  final String? model;

  Map<String, dynamic> toJson() => {
        'name': name,
        'platform': platform,
        if (manufacturer != null) 'manufacturer': manufacturer,
        if (model != null) 'model': model,
      };

  factory EvidenceDevice.fromJson(Map<String, dynamic> json) {
    return EvidenceDevice(
      name: json['name'] as String? ?? 'Unknown device',
      platform: json['platform'] as String? ?? 'unknown',
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
    );
  }
}
