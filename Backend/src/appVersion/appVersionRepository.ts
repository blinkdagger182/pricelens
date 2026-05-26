import { createSupabaseClient } from "../supabase/client.js";
import type { AppVersionPlatform, AppVersionPolicyResponse, AppVersionPolicyRow } from "./types.js";

export async function getAppVersionPolicy(platform: AppVersionPlatform): Promise<AppVersionPolicyResponse | null> {
  const supabase = createSupabaseClient();
  const { data, error } = await supabase
    .from("app_version_policies")
    .select("platform, minimum_supported_version, latest_version, is_enabled, update_title, update_message, release_notes, app_store_url, updated_at")
    .eq("platform", platform)
    .eq("is_enabled", true)
    .maybeSingle();

  if (error) {
    if (error.message.includes("app_version_policies")) {
      return null;
    }

    throw new Error(`Failed to fetch app version policy: ${error.message}`);
  }

  return data ? toAppVersionPolicyResponse(data as AppVersionPolicyRow) : null;
}

function toAppVersionPolicyResponse(row: AppVersionPolicyRow): AppVersionPolicyResponse {
  return {
    platform: row.platform,
    minimumSupportedVersion: row.minimum_supported_version,
    latestVersion: row.latest_version,
    updateTitle: row.update_title ?? "Update available",
    updateMessage: row.update_message ?? "Install the latest version for the newest fixes and improvements.",
    releaseNotes: row.release_notes ?? [],
    appStoreURL: row.app_store_url,
    policyUpdatedAt: row.updated_at
  };
}
