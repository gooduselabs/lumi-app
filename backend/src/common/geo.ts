/** Location privacy helpers: we only ever persist / compare a coarsened grid point. */

/** Grid step in degrees (0.01° ≈ 1.1 km latitude). */
export const GRID_DEG = 0.01;
const EARTH_KM = 6371;

export interface LatLng {
  lat: number;
  lng: number;
}

export function isValidLatLng(lat: unknown, lng: unknown): boolean {
  return (
    typeof lat === 'number' && typeof lng === 'number' && Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
  );
}

/** Snap to the centre of a ~1 km cell so the exact fix can never be recovered. */
export function coarsen({ lat, lng }: LatLng): LatLng {
  const snap = (v: number) => Math.round((Math.floor(v / GRID_DEG) + 0.5) * GRID_DEG * 1e6) / 1e6;
  return { lat: Math.min(90, Math.max(-90, snap(lat))), lng: Math.min(180, Math.max(-180, snap(lng))) };
}

export function haversineKm(a: LatLng, b: LatLng): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_KM * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * Approximate distance shown to other users: never below 1 km (grid resolution),
 * whole km under 10, then rounded to 5 km buckets.
 */
export function approxKm(km: number): number {
  if (km < 1.5) return 1;
  if (km < 10) return Math.round(km);
  return Math.round(km / 5) * 5;
}

const B32 = '0123456789bcdefghjkmnpqrstuvwxyz';

export function geohash({ lat, lng }: LatLng, precision = 6): string {
  let latR = [-90, 90];
  let lngR = [-180, 180];
  let out = '';
  let bit = 0;
  let ch = 0;
  let even = true;
  while (out.length < precision) {
    const r = even ? lngR : latR;
    const v = even ? lng : lat;
    const mid = (r[0] + r[1]) / 2;
    if (v >= mid) {
      ch = (ch << 1) | 1;
      r[0] = mid;
    } else {
      ch <<= 1;
      r[1] = mid;
    }
    if (even) lngR = r;
    else latR = r;
    even = !even;
    if (++bit === 5) {
      out += B32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return out;
}

/** Bounding box (degrees) that contains every point within `km` of `c`. */
export function boundingBox(c: LatLng, km: number) {
  const dLat = km / 111.32;
  const cos = Math.max(0.01, Math.cos((c.lat * Math.PI) / 180));
  const dLng = km / (111.32 * cos);
  return { minLat: c.lat - dLat, maxLat: c.lat + dLat, minLng: c.lng - dLng, maxLng: c.lng + dLng };
}
