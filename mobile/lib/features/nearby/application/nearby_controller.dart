import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user.dart';
import '../../profile/data/profile_repository.dart';

class NearbyFilter {
  const NearbyFilter({this.radiusKm = 25, this.minAge = 18, this.maxAge = 99, this.gender = 'ANY'});
  final int radiusKm;
  final int minAge;
  final int maxAge;
  final String gender;

  NearbyFilter copyWith({int? radiusKm, int? minAge, int? maxAge, String? gender}) => NearbyFilter(
        radiusKm: radiusKm ?? this.radiusKm,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        gender: gender ?? this.gender,
      );

  @override
  bool operator ==(Object other) =>
      other is NearbyFilter && other.radiusKm == radiusKm && other.minAge == minAge && other.maxAge == maxAge && other.gender == gender;
  @override
  int get hashCode => Object.hash(radiusKm, minAge, maxAge, gender);
}

const kRadiusOptions = [5, 10, 25, 50, 100];

final nearbyFilterProvider = NotifierProvider<NearbyFilterController, NearbyFilter>(NearbyFilterController.new);

class NearbyFilterController extends Notifier<NearbyFilter> {
  @override
  NearbyFilter build() {
    final me = ref.read(meProvider);
    return NearbyFilter(minAge: me?.agePrefMin ?? 18, maxAge: me?.agePrefMax ?? 99);
  }

  void set(NearbyFilter f) => state = f;
}

/// Users near me with the current filter. Empty when location is not shared / hidden.
final nearbyUsersProvider = FutureProvider.autoDispose<List<PublicUser>>((ref) async {
  final f = ref.watch(nearbyFilterProvider);
  final me = ref.watch(meProvider);
  if (me == null || !me.hasLocation || me.locationHidden) return const [];
  return ref.read(profileRepositoryProvider).nearby(radiusKm: f.radiusKm, minAge: f.minAge, maxAge: f.maxAge, gender: f.gender);
});

/// Shared location actions (Discover "prefer nearby", Nearby screen, Settings).
final locationActionsProvider = Provider((ref) => LocationActions(ref));

class LocationActions {
  LocationActions(this._ref);
  final Ref _ref;

  /// Asks permission, reads a low-accuracy fix and uploads it. Throws [LocationFailure].
  Future<Me> share() async {
    final pos = await _ref.read(locationServiceProvider).current();
    final repo = _ref.read(profileRepositoryProvider);
    var me = await repo.setLocation(pos.lat, pos.lng);
    if (me.locationHidden) me = await repo.update({'locationHidden': false});
    _ref.read(authControllerProvider.notifier).updateMe(me);
    return me;
  }

  Future<Me> setHidden(bool hidden) async {
    final me = await _ref.read(profileRepositoryProvider).update({'locationHidden': hidden});
    _ref.read(authControllerProvider.notifier).updateMe(me);
    return me;
  }

  Future<Me> clear() async {
    final me = await _ref.read(profileRepositoryProvider).clearLocation();
    _ref.read(authControllerProvider.notifier).updateMe(me);
    return me;
  }

  Future<Me> setAgeRange(int min, int max) async {
    final me = await _ref.read(profileRepositoryProvider).update({'agePrefMin': min, 'agePrefMax': max});
    _ref.read(authControllerProvider.notifier).updateMe(me);
    return me;
  }
}
