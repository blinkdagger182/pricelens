import cron from "node-cron";
import { config } from "./config.js";
import { createApp } from "./app.js";
import { syncLatestRates } from "./rates/rateService.js";

const app = createApp();

cron.schedule(config.RATE_SYNC_CRON, async () => {
  try {
    const result = await syncLatestRates(config.EXCHANGE_RATE_BASE_CURRENCY);
    console.log(`[rates] ${result.status} ${Object.keys(result.rates.rates).length} ${result.rates.baseCurrency} rates. next=${result.rates.nextUpdateAt}`);
  } catch (error) {
    console.error("[rates] scheduled sync failed", error);
  }
});

app.listen(config.PORT, () => {
  console.log(`PriceLens backend listening on :${config.PORT}`);
});
