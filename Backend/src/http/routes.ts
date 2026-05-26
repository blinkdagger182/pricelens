import type { Router } from "express";
import express from "express";
import { z } from "zod";
import { getAppVersionPolicy } from "../appVersion/appVersionRepository.js";
import { config } from "../config.js";
import { convertAmount, getLatestRates, syncLatestRates } from "../rates/rateService.js";

export function createRouter(): Router {
  const router = express.Router();

  router.get("/health", (_request, response) => {
    response.json({ ok: true, service: "pricelens-backend" });
  });

  router.get("/rates/latest", async (request, response, next) => {
    try {
      const rates = await getLatestRates(config.EXCHANGE_RATE_BASE_CURRENCY);
      response.json(rates);
    } catch (error) {
      next(error);
    }
  });

  router.get("/rates/convert", async (request, response, next) => {
    try {
      const query = z.object({
        amount: z.coerce.number().positive(),
        from: z.string().length(3),
        to: z.string().length(3)
      }).parse(request.query);
      const rates = await getLatestRates(config.EXCHANGE_RATE_BASE_CURRENCY);
      const convertedAmount = convertAmount(query.amount, query.from, query.to, rates);

      response.json({
        amount: query.amount,
        from: query.from.toUpperCase(),
        to: query.to.toUpperCase(),
        convertedAmount,
        rates
      });
    } catch (error) {
      next(error);
    }
  });

  router.get("/app-version/ios", async (request, response, next) => {
    try {
      const query = z.object({
        version: z.string().optional()
      }).parse(request.query);
      const policy = await getAppVersionPolicy("ios");

      if (!policy) {
        response.status(404).json({ error: "No active iOS app version policy" });
        return;
      }

      response.json({
        ...policy,
        currentVersion: query.version ?? null
      });
    } catch (error) {
      next(error);
    }
  });

  router.get("/tasks/sync-rates", async (request, response, next) => {
    try {
      if (!isAuthorizedSyncRequest(request, false)) {
        response.status(401).json({ error: "Unauthorized" });
        return;
      }

      const result = await syncLatestRates(config.EXCHANGE_RATE_BASE_CURRENCY, false);
      response.json({ ok: true, triggeredBy: "cron", ...result });
    } catch (error) {
      next(error);
    }
  });

  router.post("/tasks/sync-rates", async (request, response, next) => {
    try {
      if (!isAuthorizedSyncRequest(request, true)) {
        response.status(401).json({ error: "Unauthorized" });
        return;
      }

      const query = z.object({ force: z.coerce.boolean().optional() }).parse(request.query);
      const result = await syncLatestRates(config.EXCHANGE_RATE_BASE_CURRENCY, query.force ?? false);
      response.json({ ok: true, triggeredBy: "manual", ...result });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

function isAuthorizedSyncRequest(request: express.Request, allowManual: boolean): boolean {
  if (config.CRON_SECRET) {
    return request.header("authorization") === `Bearer ${config.CRON_SECRET}`;
  }

  const isVercelCron = request.header("x-vercel-cron") === "1";
  return isVercelCron || (allowManual && process.env.NODE_ENV !== "production");
}
