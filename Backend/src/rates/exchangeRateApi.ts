import { config, requireEnv } from "../config.js";
import type { RateMap } from "./types.js";

type ExchangeRateApiResponse = {
  result: "success" | "error";
  documentation?: string;
  terms_of_use?: string;
  time_last_update_unix?: number;
  time_last_update_utc?: string;
  time_next_update_unix?: number;
  time_next_update_utc?: string;
  base_code?: string;
  conversion_rates?: RateMap;
  "error-type"?: string;
};

export type FetchedRates = {
  baseCurrency: string;
  effectiveDate: string;
  fetchedAt: string;
  nextUpdateAt: string;
  rates: RateMap;
  rawPayload: ExchangeRateApiResponse;
};

export async function fetchLatestRates(baseCurrency = config.EXCHANGE_RATE_BASE_CURRENCY): Promise<FetchedRates> {
  const base = baseCurrency.toUpperCase();
  const url = `https://v6.exchangerate-api.com/v6/${requireEnv("EXCHANGE_RATE_API_KEY")}/latest/${base}`;
  const response = await fetch(url, {
    headers: {
      accept: "application/json"
    }
  });

  if (!response.ok) {
    throw new Error(`ExchangeRate-API request failed with HTTP ${response.status}`);
  }

  const payload = (await response.json()) as ExchangeRateApiResponse;
  if (payload.result !== "success" || !payload.conversion_rates) {
    throw new Error(`ExchangeRate-API returned ${payload["error-type"] ?? "an unknown error"}`);
  }

  const rates = Object.fromEntries(
    Object.entries(payload.conversion_rates)
      .filter((entry): entry is [string, number] => typeof entry[1] === "number")
      .map(([code, rate]) => [code.toUpperCase(), rate])
  );

  if (!rates[base]) {
    rates[base] = 1;
  }

  const fetchedAt = new Date().toISOString();
  const updateDate = payload.time_last_update_unix
    ? new Date(payload.time_last_update_unix * 1000)
    : new Date(fetchedAt);
  const nextUpdateAt = payload.time_next_update_unix
    ? new Date(payload.time_next_update_unix * 1000).toISOString()
    : new Date(updateDate.getTime() + 24 * 60 * 60 * 1000).toISOString();
  const effectiveDate = updateDate.toISOString().slice(0, 10);

  return {
    baseCurrency: payload.base_code ?? base,
    effectiveDate,
    fetchedAt,
    nextUpdateAt,
    rates,
    rawPayload: payload
  };
}
