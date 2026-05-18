import { config } from "../config.js";
import { fetchLatestRates } from "./exchangeRateApi.js";
import { getLatestSnapshot, upsertSnapshot } from "./rateRepository.js";
import type { LatestRatesResponse } from "./types.js";

export type SyncRatesResult = {
  status: "updated" | "skipped";
  reason?: string;
  rates: LatestRatesResponse;
};

export async function syncLatestRates(baseCurrency = config.EXCHANGE_RATE_BASE_CURRENCY, force = false): Promise<SyncRatesResult> {
  const latest = await getLatestSnapshot(baseCurrency);
  if (!force && latest && new Date(latest.nextUpdateAt).getTime() > Date.now()) {
    return {
      status: "skipped",
      reason: `Next provider update is due at ${latest.nextUpdateAt}`,
      rates: latest
    };
  }

  const fetched = await fetchLatestRates(baseCurrency);
  const rates = await upsertSnapshot(fetched);
  return { status: "updated", rates };
}

export async function getLatestRates(baseCurrency = config.EXCHANGE_RATE_BASE_CURRENCY): Promise<LatestRatesResponse> {
  const latest = await getLatestSnapshot(baseCurrency);
  if (latest) {
    return latest;
  }

  return (await syncLatestRates(baseCurrency, true)).rates;
}

export function convertAmount(amount: number, from: string, to: string, rates: LatestRatesResponse): number {
  const source = from.toUpperCase();
  const target = to.toUpperCase();
  const sourceRate = rates.rates[source];
  const targetRate = rates.rates[target];

  if (!sourceRate) {
    throw new Error(`Missing rate for ${source}`);
  }

  if (!targetRate) {
    throw new Error(`Missing rate for ${target}`);
  }

  // Rates are expressed as currency units per one base currency unit.
  const amountInBase = amount / sourceRate;
  return amountInBase * targetRate;
}
