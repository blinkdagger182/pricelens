export type AppVersionPlatform = "ios";

export type AppVersionPolicyRow = {
  platform: AppVersionPlatform;
  minimum_supported_version: string;
  latest_version: string;
  is_enabled: boolean;
  update_title: string | null;
  update_message: string | null;
  release_notes: string[] | null;
  app_store_url: string | null;
  updated_at: string;
};

export type AppVersionPolicyResponse = {
  platform: AppVersionPlatform;
  minimumSupportedVersion: string;
  latestVersion: string;
  updateTitle: string;
  updateMessage: string;
  releaseNotes: string[];
  appStoreURL: string | null;
  policyUpdatedAt: string;
};
