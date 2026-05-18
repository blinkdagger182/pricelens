import { createSupabaseClient } from "../supabase/client.js";
import type { ExchangeRateSnapshot, LatestRatesResponse, RateMap } from "./types.js";

type UpsertSnapshotInput = {
  baseCurrency: string;
  effectiveDate: string;
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
        fetched_at: input.fetchedAt,
        next_update_at: input.nextUpdateAt,
        rates: input.rates,
        raw_payload: input.rawPayload
      },
      { onConflict: "base_currency,effective_date" }
    )
    .select("id, base_currency, provider, effective_date, fetched_at, next_update_at, rates")
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
    .select("id, base_currency, provider, effective_date, fetched_at, next_update_at, rates")
    .eq("base_currency", baseCurrency.toUpperCase())
    .order("effective_date", { ascending: false })
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
    fetchedAt: snapshot.fetched_at,
    nextUpdateAt: snapshot.next_update_at,
    rates: snapshot.rates
  };
}
