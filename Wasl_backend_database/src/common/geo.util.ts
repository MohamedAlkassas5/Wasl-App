/**
 * Geographic helpers shared across pricing and driver-matching.
 *
 * We use the haversine great-circle distance for V1. It is accurate to well
 * under 1% at city scale and needs no PostGIS extension. The signatures are
 * deliberately simple so this can later be swapped for PostGIS `ST_Distance`
 * queries without touching callers.
 */

const EARTH_RADIUS_KM = 6371;

export interface GeoPoint {
  latitude: number;
  longitude: number;
}

const toRad = (deg: number): number => (deg * Math.PI) / 180;

/**
 * Great-circle distance between two lat/lng points, in kilometres.
 * Returns 0 for identical points and never throws on valid finite numbers.
 */
export function haversineKm(a: GeoPoint, b: GeoPoint): number {
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;

  return EARTH_RADIUS_KM * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Rounds a distance to a sensible 2-decimal km value. */
export function roundKm(km: number): number {
  return Math.round(km * 100) / 100;
}

/** Basic sanity check for coordinates coming from a client. */
export function isValidCoordinate(
  lat: number | undefined | null,
  lng: number | undefined | null,
): lat is number {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    // reject the (0,0) null-island fix that usually means "no GPS yet"
    !(lat === 0 && lng === 0)
  );
}
