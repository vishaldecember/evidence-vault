import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../models/evidence_device.dart';
import '../models/evidence_location.dart';
import '../models/evidence_metadata.dart';
import 'capture/capture_provenance.dart';

abstract final class MetadataService {
  static const _uuid = Uuid();

  static Future<EvidenceMetadata> collect() async {
    final snapshot = await collectAtCapture();
    return EvidenceMetadata(
      evidenceId: _uuid.v4(),
      capturedAt: DateTime.now(),
      timezone: DateTime.now().timeZoneName,
      device: snapshot.device,
      location: snapshot.location,
    );
  }

  /// Test seam — delayed or unavailable GPS without touching Geolocator.
  @visibleForTesting
  static Future<CaptureProvenanceSnapshot> Function()? debugCollectAtCapture;

  /// Device + location for the capture event. Never invents coordinates or model.
  static Future<CaptureProvenanceSnapshot> collectAtCapture() async {
    final override = debugCollectAtCapture;
    if (override != null) {
      return override();
    }
    if (_inFlutterTest) {
      return const CaptureProvenanceSnapshot(
        device: EvidenceDevice(name: '', platform: 'test'),
        location: EvidenceLocation(),
        locationStatus: CaptureLocationStatus.skipped,
      );
    }

    final device = await _collectDevice();
    final locationResult = await _collectLocation();
    return CaptureProvenanceSnapshot(
      device: device,
      location: locationResult.location,
      locationStatus: locationResult.status,
    );
  }

  static Future<CaptureProvenanceSnapshot> retryLocation(
    CaptureProvenanceSnapshot previous,
  ) async {
    if (_inFlutterTest) {
      return previous;
    }
    final locationResult = await _collectLocation(requestPermission: true);
    return CaptureProvenanceSnapshot(
      device: previous.device,
      location: locationResult.location,
      locationStatus: locationResult.status,
    );
  }

  /// Manufacturer + model, never a generic "Android" / "Phone" when APIs work.
  static String formatDeviceSource({
    required String manufacturer,
    required String model,
  }) {
    final mfg = manufacturer.trim();
    final mdl = model.trim();
    if (mfg.isEmpty && mdl.isEmpty) {
      return '';
    }
    if (mfg.isEmpty) {
      return mdl;
    }
    if (mdl.isEmpty) {
      return _titleCase(mfg);
    }
    final titled = _titleCase(mfg);
    final lowerModel = mdl.toLowerCase();
    if (lowerModel.startsWith(mfg.toLowerCase()) ||
        lowerModel.startsWith(titled.toLowerCase())) {
      return mdl;
    }
    return '$titled $mdl';
  }

  static bool get _inFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  static Future<EvidenceDevice> _collectDevice() async {
    final plugin = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        return const EvidenceDevice(name: 'Web browser', platform: 'web');
      }

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final manufacturer = info.manufacturer.trim();
        final model = info.model.trim();
        final name = formatDeviceSource(
          manufacturer: manufacturer,
          model: model,
        );
        return EvidenceDevice(
          name: name.isNotEmpty ? name : 'Android device',
          platform: 'android',
          manufacturer: manufacturer.isEmpty ? null : manufacturer,
          model: model.isEmpty ? null : model,
        );
      }

      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final model = info.model.trim();
        final name = info.name.trim();
        final display = model.isNotEmpty
            ? model
            : (name.isNotEmpty ? name : 'iOS device');
        return EvidenceDevice(
          name: display,
          platform: 'ios',
          manufacturer: 'Apple',
          model: model.isEmpty ? null : model,
        );
      }

      if (Platform.isWindows) {
        return const EvidenceDevice(name: 'Windows PC', platform: 'windows');
      }

      if (Platform.isMacOS) {
        return const EvidenceDevice(name: 'Mac', platform: 'macos');
      }

      if (Platform.isLinux) {
        return const EvidenceDevice(name: 'Linux device', platform: 'linux');
      }
    } catch (_) {
      // Fall through to unknown device.
    }

    return EvidenceDevice(
      name: 'Unknown device',
      platform: kIsWeb ? 'web' : Platform.operatingSystem,
    );
  }

  static Future<({EvidenceLocation location, CaptureLocationStatus status})>
      _collectLocation({bool requestPermission = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          location: const EvidenceLocation(),
          status: CaptureLocationStatus.servicesDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return (
          location: const EvidenceLocation(),
          status: CaptureLocationStatus.permissionPermanentlyDenied,
        );
      }
      if (permission == LocationPermission.denied) {
        return (
          location: const EvidenceLocation(),
          status: CaptureLocationStatus.permissionDenied,
        );
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 2)) {
          position = last;
        }
      }

      if (position == null) {
        return (
          location: const EvidenceLocation(),
          status: CaptureLocationStatus.temporarilyUnavailable,
        );
      }

      return (
        location: EvidenceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
        status: CaptureLocationStatus.captured,
      );
    } catch (_) {
      return (
        location: const EvidenceLocation(),
        status: CaptureLocationStatus.temporarilyUnavailable,
      );
    }
  }
}
