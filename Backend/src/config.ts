import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(8787),
  NODE_ENV: z.string().default("development"),
  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().optional(),
  EXCHANGE_RATE_API_KEY: z.string().optional(),
  EXCHANGE_RATE_BASE_CURRENCY: z.string().length(3).default("USD"),
  SUPPORTED_CURRENCIES: z.string().default("MYR,JPY,KRW,THB,SGD,IDR,USD,EUR,GBP,AUD,CAD,CNY,HKD,TWD,PHP,VND"),
  RATE_SYNC_CRON: z.string().default("0 3 * * *"),
  CRON_SECRET: z.string().optional()
});

export const config = envSchema.parse(process.env);

export const supportedCurrencies = config.SUPPORTED_CURRENCIES
  .split(",")
  .map((code) => code.trim().toUpperCase())
  .filter(Boolean);

export function requireEnv(name: "SUPABASE_URL" | "SUPABASE_SERVICE_ROLE_KEY" | "EXCHANGE_RATE_API_KEY"): string {
  const value = config[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}
