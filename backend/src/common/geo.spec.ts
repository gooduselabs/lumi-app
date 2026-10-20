import { approxKm, boundingBox, coarsen, geohash, haversineKm, isValidLatLng } from './geo';

describe('geo', () => {
  it('coarsens to the centre of a ~1km cell', () => {
    const c = coarsen({ lat: 10.77689, lng: 106.70081 });
    expect(c).toEqual({ lat: 10.775, lng: 106.705 });
    // Two nearby fixes in the same cell are indistinguishable.
    expect(coarsen({ lat: 10.7701, lng: 106.7099 })).toEqual(c);
    expect(haversineKm(c, { lat: 10.77689, lng: 106.70081 })).toBeLessThan(1);
  });
  it('handles negatives', () => {
    expect(coarsen({ lat: -33.8688, lng: 151.2093 })).toEqual({ lat: -33.865, lng: 151.205 });
  });
  it('computes distances', () => {
    expect(haversineKm({ lat: 10.7769, lng: 106.7009 }, { lat: 21.0285, lng: 105.8542 })).toBeCloseTo(1140, -1);
  });
  it('rounds distances shown to others', () => {
    expect(approxKm(0.2)).toBe(1);
    expect(approxKm(3.4)).toBe(3);
    expect(approxKm(12.6)).toBe(15);
  });
  it('encodes geohash', () => {
    expect(geohash({ lat: 57.64911, lng: 10.40744 }, 11)).toBe('u4pruydqqvj');
  });
  it('validates coordinates', () => {
    expect(isValidLatLng(10, 106)).toBe(true);
    expect(isValidLatLng(91, 0)).toBe(false);
    expect(isValidLatLng(NaN, 0)).toBe(false);
  });
  it('bounding box contains radius', () => {
    const b = boundingBox({ lat: 10, lng: 106 }, 10);
    expect(b.maxLat - 10).toBeCloseTo(0.0898, 3);
  });
});
