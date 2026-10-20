import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

enum LocationIssue { serviceOff, denied, deniedForever }

class LocationFailure implements Exception {
  const LocationFailure(this.issue);
  final LocationIssue issue;
}

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());

/// Thin wrapper around geolocator with explicit permission handling.
/// Only a low-accuracy fix is requested: the server rounds it to ~1 km anyway.
class LocationService {
  const LocationService();

  Future<({double lat, double lng})> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const LocationFailure(LocationIssue.serviceOff);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) throw const LocationFailure(LocationIssue.deniedForever);
    if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
      throw const LocationFailure(LocationIssue.denied);
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
    );
    return (lat: p.latitude, lng: p.longitude);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

