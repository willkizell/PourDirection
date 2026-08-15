import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY");
// Injected automatically by the Supabase Edge runtime.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// How long a cached Google result is served before re-fetching.
// Place lists, ratings and weekly hours barely change day to day; open/closed
// status is computed at serve time from the cached weekly schedule, so a long
// TTL does not make "Open now" stale.
const CACHE_TTL_HOURS = 24;

interface TypeConfig {
  includedTypes?: string[];
  excludedTypes?: string[];
  openNowOnly?: boolean; // filtered at serve time from cached hours, never sent to Google
  radius: number;
  textQuery?: string; // present → use Text Search instead of Nearby Search
}

function resolveTypeConfig(type: string): TypeConfig {
  switch (type) {
    case "bar":
      return {
        includedTypes: ["bar"],
        excludedTypes: ["community_center", "sports_club", "fitness_center"],
        radius: 1500,
      };

    case "restaurant":
      return {
        includedTypes: ["restaurant"],
        excludedTypes: ["fast_food_restaurant", "meal_takeaway"],
        radius: 1500,
      };

    case "restaurantLateNight":
      return {
        includedTypes: [
          "restaurant",
          "fast_food_restaurant",
          "meal_takeaway",
          "meal_delivery",
          "sandwich_shop",
          "pizza_restaurant",
          "hamburger_restaurant",
          "chinese_restaurant",
          "sushi_restaurant",
        ],
        openNowOnly: true,
        radius: 1500,
      };

    case "night_club":
    case "club":
      return { includedTypes: ["night_club"], radius: 12000 };

    case "dispensary":
      return { textQuery: "cannabis dispensary", radius: 3000 };

    case "liquor_store":
      return { textQuery: "liquor store", radius: 3000 };

    default:
      return { includedTypes: [type], radius: 1500 };
  }
}

// Fields requested from Google. regularOpeningHours (weekly schedule) replaces
// currentOpeningHours so results stay valid for the full cache TTL; open-now is
// computed per request from periods + utcOffsetMinutes.
const FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.photos",
  "places.types",
  "places.userRatingCount",
  "places.regularOpeningHours",
  "places.utcOffsetMinutes",
].join(",");

// ── Shared cache (Postgres via PostgREST) ────────────────────────────────────
// One Google fetch per ~1 km grid cell / type / radius bucket / 24 h, shared by
// every user. Failures fall through to a direct Google fetch.

function cacheHeaders(): HeadersInit {
  return {
    apikey: SUPABASE_SERVICE_ROLE_KEY!,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };
}

async function cacheGet(key: string): Promise<StoredPlace[] | null> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return null;
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/places_cache?cache_key=eq.${encodeURIComponent(key)}&select=payload,expires_at`,
      { headers: cacheHeaders() },
    );
    if (!res.ok) return null;
    const rows = await res.json();
    const row = rows?.[0];
    if (!row) return null;
    if (new Date(row.expires_at).getTime() < Date.now()) return null;
    return row.payload as StoredPlace[];
  } catch (err) {
    console.error("[nearby-places] cache read failed:", err);
    return null;
  }
}

async function cacheSet(key: string, payload: StoredPlace[]): Promise<void> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return;
  try {
    const expiresAt = new Date(Date.now() + CACHE_TTL_HOURS * 3600 * 1000).toISOString();
    await fetch(`${SUPABASE_URL}/rest/v1/places_cache`, {
      method: "POST",
      headers: {
        ...cacheHeaders(),
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify([{ cache_key: key, payload, expires_at: expiresAt }]),
    });
  } catch (err) {
    console.error("[nearby-places] cache write failed:", err);
  }
}

// ── Stored / response shapes ─────────────────────────────────────────────────

interface OpeningPoint {
  day: number; // 0 = Sunday
  hour: number;
  minute: number;
}

interface OpeningPeriod {
  open?: OpeningPoint;
  close?: OpeningPoint;
}

interface StoredPlace {
  id: string;
  displayName: { text: string };
  formattedAddress: string | null;
  location: { latitude: number; longitude: number };
  rating: number | null;
  photoUri?: string; // key-free googleusercontent URL, resolved at cache-fill time
  types: string[];
  userRatingCount: number | null;
  weekdayDescriptions: string[] | null;
  periods: OpeningPeriod[] | null;
  utcOffsetMinutes: number | null;
}

// ── Open-now computation from the cached weekly schedule ─────────────────────

const MINUTES_PER_WEEK = 7 * 24 * 60;

function computeIsOpenNow(place: StoredPlace): boolean | null {
  const periods = place.periods;
  if (!periods || periods.length === 0) return null;

  // 24/7 places: a single period with an open and no close.
  if (periods.length === 1 && periods[0].open && !periods[0].close) return true;

  const offset = place.utcOffsetMinutes ?? 0;
  const local = new Date(Date.now() + offset * 60 * 1000);
  const nowMinutes =
    local.getUTCDay() * 1440 + local.getUTCHours() * 60 + local.getUTCMinutes();

  for (const period of periods) {
    if (!period.open || !period.close) continue;
    const start = period.open.day * 1440 + period.open.hour * 60 + period.open.minute;
    let end = period.close.day * 1440 + period.close.hour * 60 + period.close.minute;
    if (end <= start) end += MINUTES_PER_WEEK; // spans past midnight / wraps the week
    if (
      (nowMinutes >= start && nowMinutes < end) ||
      (nowMinutes + MINUTES_PER_WEEK >= start && nowMinutes + MINUTES_PER_WEEK < end)
    ) {
      return true;
    }
  }
  return false;
}

function toResponsePlace(place: StoredPlace) {
  return {
    id: place.id,
    displayName: place.displayName,
    formattedAddress: place.formattedAddress,
    location: place.location,
    rating: place.rating,
    photoUri: place.photoUri,
    types: place.types,
    userRatingCount: place.userRatingCount,
    isOpenNow: computeIsOpenNow(place),
    weekdayDescriptions: place.weekdayDescriptions,
  };
}

// ── Photo resolution ─────────────────────────────────────────────────────────
// Resolve each place's first photo to its final googleusercontent URL once at
// cache-fill time. The URL contains no API key (the old implementation shipped
// the raw key to every client) and one photo request is billed per place per
// TTL instead of per client image load.

async function resolvePhotoUri(photoName: string | null): Promise<string | undefined> {
  if (!photoName || !GOOGLE_PLACES_API_KEY) return undefined;
  try {
    const res = await fetch(
      `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=800&skipHttpRedirect=true`,
      { headers: { "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY } },
    );
    if (!res.ok) return undefined;
    const data = await res.json();
    return data.photoUri ?? undefined;
  } catch {
    return undefined;
  }
}

async function toStoredPlaces(rawPlaces: any[]): Promise<StoredPlace[]> {
  return await Promise.all(
    rawPlaces.map(async (place: any): Promise<StoredPlace> => {
      const photoName: string | null = place.photos?.[0]?.name ?? null;
      return {
        id: place.id ?? place.displayName?.text,
        displayName: place.displayName,
        formattedAddress: place.formattedAddress ?? null,
        location: place.location,
        rating: place.rating ?? null,
        photoUri: await resolvePhotoUri(photoName),
        types: place.types ?? [],
        userRatingCount: place.userRatingCount ?? null,
        weekdayDescriptions: place.regularOpeningHours?.weekdayDescriptions ?? null,
        periods: place.regularOpeningHours?.periods ?? null,
        utcOffsetMinutes: place.utcOffsetMinutes ?? null,
      };
    }),
  );
}

// ── Google fetchers ──────────────────────────────────────────────────────────

async function googleTextSearch(
  textQuery: string,
  lat: number,
  lng: number,
  radius: number,
): Promise<any[]> {
  const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY!,
      "X-Goog-FieldMask": FIELD_MASK,
    },
    body: JSON.stringify({
      textQuery,
      locationBias: { circle: { center: { latitude: lat, longitude: lng }, radius } },
      maxResultCount: 20,
    }),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error(`[nearby-places] Google Text Search error ("${textQuery}"):`, data);
    return [];
  }
  return data.places ?? [];
}

async function googleNearbySearch(
  config: TypeConfig,
  lat: number,
  lng: number,
  radius: number,
): Promise<any[]> {
  const requestBody: Record<string, unknown> = {
    maxResultCount: 20,
    locationRestriction: {
      circle: { center: { latitude: lat, longitude: lng }, radius },
    },
  };
  if (config.includedTypes?.length) requestBody.includedTypes = config.includedTypes;
  if (config.excludedTypes?.length) requestBody.excludedTypes = config.excludedTypes;

  const res = await fetch("https://places.googleapis.com/v1/places:searchNearby", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY!,
      "X-Goog-FieldMask": FIELD_MASK,
    },
    body: JSON.stringify(requestBody),
  });
  const data = await res.json();
  if (!res.ok) {
    console.error("[nearby-places] Google Places error:", data);
    return [];
  }
  return data.places ?? [];
}

// ── Handler ──────────────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const { lat, lng, type, radius: clientRadius } = await req.json();

    const resolvedType =
      typeof type === "string" && type.trim() !== "" ? type.trim() : "bar";

    const config = resolveTypeConfig(resolvedType);

    // Use client-provided radius if present, otherwise fall back to defaults.
    // iOS sends walkingDistanceMeters for suggestion bars/restaurants/dispensaries,
    // searchAreaMeters for clubs and all map categories.
    const radius =
      typeof clientRadius === "number" && clientRadius > 0
        ? clientRadius
        : config.radius;

    if (!GOOGLE_PLACES_API_KEY) {
      console.error("GOOGLE_PLACES_API_KEY missing");
      return new Response(JSON.stringify({ places: [] }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Cache key: ~1.1 km location grid + type + 500 m radius bucket.
    const gridLat = lat.toFixed(2);
    const gridLng = lng.toFixed(2);
    const radiusBucket = Math.max(500, Math.round(radius / 500) * 500);
    const cacheKey = `v2:${resolvedType}:${gridLat}:${gridLng}:${radiusBucket}`;

    let stored = await cacheGet(cacheKey);
    const cacheHit = stored !== null;

    if (!stored) {
      const rawPlaces = config.textQuery
        ? await googleTextSearch(config.textQuery, lat, lng, radius)
        : await googleNearbySearch(config, lat, lng, radius);
      stored = await toStoredPlaces(rawPlaces);
      if (stored.length > 0) {
        await cacheSet(cacheKey, stored);
      }
    }

    let places = stored.map(toResponsePlace);

    // Late-night restaurants: only places open right now (computed from the
    // cached weekly schedule, so this stays correct for the whole TTL).
    if (config.openNowOnly) {
      places = places.filter((p) => p.isOpenNow !== false);
    }

    console.log(
      `[nearby-places] type=${resolvedType} cache=${cacheHit ? "HIT" : "MISS"} returning ${places.length} places`,
    );

    return new Response(JSON.stringify({ places }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[nearby-places] Edge Function error:", err);
    return new Response(JSON.stringify({ places: [] }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
