import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY");

interface TypeConfig {
  includedTypes?: string[];
  excludedTypes?: string[];
  openNow?: boolean;
  radius: number;
  debug?: boolean;
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
        openNow: true,
        radius: 1500,
      };

    case "night_club":
    case "club":
      return { includedTypes: ["night_club"], radius: 12000 };

    case "dispensary":
      // Text Search override handles this
      return { radius: 3000 };

    default:
      return { includedTypes: [type], radius: 1500 };
  }
}

serve(async (req) => {
  try {
    const { lat, lng, type, radius: clientRadius } = await req.json();

    const resolvedType =
      typeof type === "string" && type.trim() !== ""
        ? type.trim()
        : "bar";

    const config = resolveTypeConfig(resolvedType);
    const { includedTypes, excludedTypes, openNow, debug } = config;

    // Use client-provided radius if present, otherwise fall back to defaults.
    // iOS sends walkingDistanceMeters for suggestion bars/restaurants/dispensaries,
    // searchAreaMeters for clubs and all map categories.
    const radius =
      typeof clientRadius === "number" && clientRadius > 0
        ? clientRadius
        : config.radius;

    console.log(`[nearby-places] type received: "${resolvedType}"`);

    if (!GOOGLE_PLACES_API_KEY) {
      console.error("GOOGLE_PLACES_API_KEY missing");
      return new Response(JSON.stringify({ places: [] }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // ============================================
    // DISPENSARY OVERRIDE USING TEXT SEARCH
    // ============================================
    if (resolvedType === "dispensary") {
      const textSearchBody = {
        textQuery: "cannabis dispensary",
        locationBias: {
          circle: {
            center: { latitude: lat, longitude: lng },
            radius,
          },
        },
        maxResultCount: 20,
      };

      const textRes = await fetch(
        "https://places.googleapis.com/v1/places:searchText",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
            "X-Goog-FieldMask": [
              "places.id",
              "places.displayName",
              "places.formattedAddress",
              "places.location",
              "places.rating",
              "places.photos",
              "places.types",
              "places.userRatingCount",
              "places.currentOpeningHours",
            ].join(","),
          },
          body: JSON.stringify(textSearchBody),
        }
      );

      const textData = await textRes.json();

      if (!textRes.ok) {
        console.error("[dispensary] Google Text Search error:", textData);
        return new Response(JSON.stringify({ places: [] }), {
          headers: { "Content-Type": "application/json" },
        });
      }

      const textPlaces = textData.places ?? [];
      console.log(
        `[nearby-places] dispensary text search returning ${textPlaces.length} places`
      );

      const mapped = textPlaces.map((place: any) => {
        const photoName = place.photos?.[0]?.name ?? null;
        const photoUri = photoName
          ? `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=800&key=${GOOGLE_PLACES_API_KEY}`
          : undefined;

        return {
          id: place.id ?? place.displayName?.text,
          displayName: place.displayName,
          formattedAddress: place.formattedAddress ?? null,
          location: place.location,
          rating: place.rating ?? null,
          photoUri,
          types: place.types ?? [],
          userRatingCount: place.userRatingCount ?? null,
          isOpenNow: place.currentOpeningHours?.openNow ?? null,
          weekdayDescriptions: place.currentOpeningHours?.weekdayDescriptions ?? null,
        };
      });

      return new Response(JSON.stringify({ places: mapped }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // ============================================
    // NORMAL NEARBY SEARCH FOR OTHER TYPES
    // ============================================

    console.log(
      `[nearby-places] includedTypes: ${JSON.stringify(
        includedTypes ?? "none"
      )}`
    );
    console.log(
      `[nearby-places] excludedTypes: ${JSON.stringify(
        excludedTypes ?? []
      )}`
    );
    console.log(`[nearby-places] radius: ${radius}m`);
    console.log(`[nearby-places] openNow: ${openNow ?? false}`);

    const requestBody: Record<string, unknown> = {
      maxResultCount: 20,
      locationRestriction: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius,
        },
      },
    };

    if (includedTypes && includedTypes.length > 0) {
      requestBody.includedTypes = includedTypes;
    }

    if (excludedTypes && excludedTypes.length > 0) {
      requestBody.excludedTypes = excludedTypes;
    }

    if (openNow) {
      requestBody.openNow = true;
    }

    const fieldMask = debug
      ? "places.displayName,places.types,places.formattedAddress,places.location,places.rating"
      : [
          "places.id",
          "places.displayName",
          "places.formattedAddress",
          "places.location",
          "places.rating",
          "places.photos",
          "places.types",
          "places.userRatingCount",
          "places.currentOpeningHours",
        ].join(",");

    const googleRes = await fetch(
      "https://places.googleapis.com/v1/places:searchNearby",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
          "X-Goog-FieldMask": fieldMask,
        },
        body: JSON.stringify(requestBody),
      }
    );

    const data = await googleRes.json();

    if (!googleRes.ok) {
      console.error("[nearby-places] Google Places error:", data);
      return new Response(JSON.stringify({ places: [] }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const rawPlaces = data.places ?? [];
    console.log(`[nearby-places] returning ${rawPlaces.length} places`);

    const places = rawPlaces.map((place: any) => {
      const photoName = place.photos?.[0]?.name ?? null;
      const photoUri = photoName
        ? `https://places.googleapis.com/v1/${photoName}/media?maxWidthPx=800&key=${GOOGLE_PLACES_API_KEY}`
        : undefined;

      return {
        id: place.id ?? place.displayName?.text,
        displayName: place.displayName,
        formattedAddress: place.formattedAddress ?? null,
        location: place.location,
        rating: place.rating ?? null,
        photoUri,
        types: place.types ?? [],
        userRatingCount: place.userRatingCount ?? null,
        isOpenNow: place.currentOpeningHours?.openNow ?? null,
        weekdayDescriptions: place.currentOpeningHours?.weekdayDescriptions ?? null,
      };
    });

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
