import { createSupabaseClient } from "../supabase/client.js";
import type { ExchangeRateSnapshot, LatestRatesResponse, RateMap } from "./types.js";

type UpsertSnapshotInput = {
  baseCurrency: string;
  effectiveDate: string;
  providerLastUpdateAt: string;
  providerLastUpdateUnix: number | null;
  providerNextUpdateAt: string;
  providerNextUpdateUnix: number | null;
  fetchedAt: string;
  nextUpdateAt: string;
  rates: RateMap;
  rawPayload: unknown;
};

export async function upsertSnapshot(input: UpsertSnapshotInput): Promise<LatestRatesResponse> {
  const supabase = createSupabaseClient();
  const { data, error } = await supabase
    .from("exchange_rate_snapshots")
    .upsert(
      {
        base_currency: input.baseCurrency.toUpperCase(),
        provider: "exchangerate-api",
        effective_date: input.effectiveDate,
        provider_last_update_at: input.providerLastUpdateAt,
        provider_last_update_unix: input.providerLastUpdateUnix,
        provider_next_update_at: input.providerNextUpdateAt,
        provider_next_update_unix: input.providerNextUpdateUnix,
        fetched_at: input.fetchedAt,
        next_update_at: input.nextUpdateAt,
        rates: input.rates,
        raw_payload: input.rawPayload
      },
      { onConflict: "base_currency,provider_last_update_at" }
    )
    .select("id, base_currency, provider, effective_date, provider_last_update_at, provider_last_update_unix, provider_next_update_at, provider_next_update_unix, fetched_at, next_update_at, rates")
    .single();

  if (error) {
    throw new Error(`Failed to upsert exchange rates: ${error.message}`);
  }

  return toLatestRatesResponse(data as ExchangeRateSnapshot);
}

export async function getLatestSnapshot(baseCurrency: string): Promise<LatestRatesResponse | null> {
  const supabase = createSupabaseClient();
  const { data, error } = await supabase
    .from("exchange_rate_snapshots")
    .select("id, base_currency, provider, effective_date, provider_last_update_at, provider_last_update_unix, provider_next_update_at, provider_next_update_unix, fetched_at, next_update_at, rates")
    .eq("base_currency", baseCurrency.toUpperCase())
    .order("provider_last_update_at", { ascending: false })
    .order("fetched_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to fetch latest exchange rates: ${error.message}`);
  }

  return data ? toLatestRatesResponse(data as ExchangeRateSnapshot) : null;
}

function toLatestRatesResponse(snapshot: ExchangeRateSnapshot): LatestRatesResponse {
  return {
    baseCurrency: snapshot.base_currency,
    provider: snapshot.provider,
    effectiveDate: snapshot.effective_date,
    providerLastUpdateAt: snapshot.provider_last_update_at,
    providerLastUpdateUnix: snapshot.provider_last_update_unix,
    providerNextUpdateAt: snapshot.provider_next_update_at,
    providerNextUpdateUnix: snapshot.provider_next_update_unix,
    fetchedAt: snapshot.fetched_at,
    nextUpdateAt: snapshot.next_update_at,
    rates: snapshot.rates
  };
}
