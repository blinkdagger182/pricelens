import { syncLatestRates } from "../rates/rateService.js";

try {
  const result = await syncLatestRates();
  console.log(`${result.status} ${Object.keys(result.rates.rates).length} rates for ${result.rates.baseCurrency}; next=${result.rates.nextUpdateAt}`);
} catch (error) {
  console.error(error);
  process.exitCode = 1;
}
