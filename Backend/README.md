# PriceLens Backend

Small TypeScript API that fetches exchange rates from ExchangeRate-API, stores a daily cache in Supabase, and exposes the latest cached rates to the iOS app.

## Setup

1. Create the Supabase table using `supabase/schema.sql`.
2. Copy `.env.example` to `.env`.
3. Fill:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `EXCHANGE_RATE_API_KEY`
   - optionally `CRON_SECRET`
4. Install and run:

```bash
npm install
npm run dev
```

## Endpoints

```http
GET /health
GET /rates/latest
GET /rates/convert?from=JPY&to=MYR&amount=1200
POST /tasks/sync-rates
Authorization: Bearer <CRON_SECRET>
```

## Notes

- The backend writes with the Supabase service role key. Do not put that key in the iOS app.
- The iOS app should use `GET /rates/latest` for rates. It should not write exchange-rate data and does not need the Supabase service role key.
- For local Simulator development, PriceLens currently points to `http://127.0.0.1:8787`.
- Before TestFlight, replace `PRICE_LENS_API_BASE_URL` in the iOS project config with your deployed HTTPS backend URL.
- `GET /rates/latest` returns the latest cached rates. It bootstraps from ExchangeRate-API if the database is empty.
- `/tasks/sync-rates` checks the cached `next_update_at` from ExchangeRate-API and skips the upstream request until that time has passed.
- This keeps ExchangeRate-API usage to roughly one request per provider update cycle.

## Vercel

This app includes a Vercel serverless entrypoint at `api/index.ts`.

Production deployment:

```text
https://pricelens-backend.vercel.app
```

Required Vercel environment variables:

```bash
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
EXCHANGE_RATE_API_KEY
EXCHANGE_RATE_BASE_CURRENCY=USD
SUPPORTED_CURRENCIES
CRON_SECRET
```

`vercel.json` configures a daily Vercel Cron run at 03:00 UTC against `/tasks/sync-rates`.
