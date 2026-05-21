export type RateMap = Record<string, number>;

export type ExchangeRateSnapshot = {
  id: string;
  base_currency: string;
  provider: string;
  effective_date: string;
  provider_last_update_at: string;
  provider_last_update_unix: number | null;
  provider_next_update_at: string;
  provider_next_update_unix: number | null;
  fetched_at: string;
  next_update_at: string;
  rates: RateMap;
};

export type LatestRatesResponse = {
  baseCurrency: string;
  provider: string;
  effectiveDate: string;
  providerLastUpdateAt: string;
  providerLastUpdateUnix: number | null;
  providerNextUpdateAt: string;
  providerNextUpdateUnix: number | null;
  fetchedAt: string;
  nextUpdateAt: string;
  rates: RateMap;
};
