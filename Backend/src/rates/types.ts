export type RateMap = Record<string, number>;

export type ExchangeRateSnapshot = {
  id: string;
  base_currency: string;
  provider: string;
  effective_date: string;
  fetched_at: string;
  next_update_at: string;
  rates: RateMap;
};

export type LatestRatesResponse = {
  baseCurrency: string;
  provider: string;
  effectiveDate: string;
  fetchedAt: string;
  nextUpdateAt: string;
  rates: RateMap;
};
