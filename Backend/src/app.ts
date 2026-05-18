import express from "express";
import { createRouter } from "./http/routes.js";
import { errorHandler } from "./http/errorHandler.js";

export function createApp() {
  const app = express();

  app.use(express.json());
  app.use(createRouter());
  app.use(errorHandler);

  return app;
}

