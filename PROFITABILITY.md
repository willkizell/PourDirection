# PourDirection — Break-Even Runbook

Where the money goes, what changed in this branch, and the steps only you can
do to finish the job. Work top to bottom; the server-side items help the
**live app immediately**, no App Store update needed.

## Where the money was going

1. **Google Places API (the whole bill).** Every screen fired its own
   searches: app launch prefetched 5 categories, the Map tab fired **10**
   searches at once (5 types × walking + wide radius), the suggestion views
   1–5 more. The only cache was 5 minutes on-device, so every user paid
   Google full price for the same downtown bars. Each search requested
   `rating`, `userRatingCount`, and `currentOpeningHours`, which bills at
   Google's top Places SKU (roughly $0.03–0.04 per request, with only a small
   free monthly allowance at that tier). A single evening session could burn
   15–25 billable requests.

2. **Place photos were billed per client image load** (~$7 per 1,000), and —
   worse — the photo URLs shipped to every phone **contained your raw Google
   API key**. Anyone could extract it from network traffic and run up your
   bill.

3. **Revenue was zero by construction.** `PurchaseManager` was a TestFlight
   mock: tapping "Upgrade to Pro" just slept 1 second and set a UserDefaults
   flag. Nobody could pay you $9.99/year, and everyone who tapped it got ads
   removed for free, killing your only other revenue stream.

4. AdMob banner: fine, but hidden on the Map tab (a high-dwell screen) and
   worth ~pennies at small scale. Ads are a garnish; cost control is the
   meal.

## What changed in this branch

- **`supabase-edge-function-nearby-places.ts` rewritten** with a shared
  Postgres cache: one Google fetch per ~1 km cell / category / radius bucket
  / 24 h, shared across *all* users. Cost now scales with unique
  neighborhoods per day, not with users or sessions. Open/closed status is
  computed per request from the cached weekly schedule
  (`regularOpeningHours` + `utcOffsetMinutes`), so "Open now" stays accurate
  despite the long TTL. Response shape is unchanged — existing installed
  apps benefit the moment you deploy.
- **Photos fixed**: the function resolves each place's photo to a key-free
  `googleusercontent.com` URL once per cache fill. One photo request per
  place per day instead of per client load, and the API key never leaves the
  server.
- **Real StoreKit 2 purchases** in `PurchaseManager` (product ID
  `com.pourdirection.pro.yearly`): purchase, restore, `Transaction.updates`
  listener, entitlement refresh. Anyone who "bought" the mock Pro gets reset
  to free automatically. `UpgradeToProView` now shows the live App Store
  price and a failure alert.
- **Client trims**: launch prefetch reduced from 5 categories to bar only;
  on-device cache TTL 5 → 15 min; per-launch `health-check` invocation
  removed.

## Your checklist (in order)

### Server (do now — helps the live app today)

1. Run `supabase-places-cache.sql` in the Supabase SQL editor (creates
   `places_cache`, RLS on, service-role only).
2. Deploy the edge function:
   `supabase functions deploy nearby-places`
3. **Rotate the Google Places API key** (Google Cloud Console → Credentials).
   The old key has been shipped inside photo URLs to every install, so treat
   it as public. On the new key:
   - Restrict it to the **Places API (New)** only.
   - Update the `GOOGLE_PLACES_API_KEY` secret in Supabase
     (`supabase secrets set GOOGLE_PLACES_API_KEY=...`).
   - Set a **budget alert** in Google Cloud Billing (e.g. $10) so surprises
     ping you instead of your card. Old-key photo URLs cached by clients
     break on rotation; new responses fix themselves within the cache TTL.
4. In the function logs, confirm `cache=HIT` lines appear after the first
   request in an area.

### App Store Connect (needed before the IAP earns anything)

5. Create an **auto-renewable subscription**, product ID exactly
   `com.pourdirection.pro.yearly`, $9.99/year (or change the constant in
   `PurchaseManager.swift` to match). Add it to a subscription group, fill
   in localization + review notes.
6. Sign the **Paid Applications agreement** and set up banking/tax if you
   haven't — purchases silently fail without it.
7. App Review requires subscription apps to link **Terms of Use (EULA) and
   Privacy Policy** on the paywall and in App Store metadata. Add those two
   links to `UpgradeToProView` before submitting (any hosted page works;
   Apple's standard EULA link is acceptable for terms).
8. Ship the app update. Test the purchase in sandbox / TestFlight first
   (sandbox Apple ID, buy, kill app, relaunch, confirm ads stay hidden;
   test Restore).

### Revenue ideas after break-even (optional)

- Show the banner on the Map tab too (currently hidden) — it's the
  highest-dwell screen.
- An **interstitial** after ending a compass session (every Nth time,
  frequency-capped) typically out-earns banners 10–20×. Keep it out of the
  compass itself.
- Give PourPro a second benefit (e.g. wider search radius or unlimited
  saved places) so the paywall sells more than ad removal.

## Expected outcome

With the shared 24 h cache, Google traffic drops from
`O(users × sessions × screens)` to `O(active neighborhoods × 5 categories
per day)` — for a small city-concentrated user base that's typically a
>90% reduction and should sit inside Google's free monthly call allowance.
Photos drop similarly. Supabase stays comfortably in free tier. From there,
every ad impression and every $9.99 subscription is profit against fixed
costs (Apple's $99/year).
