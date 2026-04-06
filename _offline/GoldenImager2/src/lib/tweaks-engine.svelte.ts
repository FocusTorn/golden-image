import { invoke } from "@tauri-apps/api/tauri";
import { listen } from "@tauri-apps/api/event";
import { notificationStore } from "./notifications";
import { vhdStore, settings } from "./store";
import { get } from "svelte/store";

const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

export class TweaksEngine {
  featuresConfig = $state<any>(null);
  auditResults = $state<any[]>([]);
  loading = $state(true);
  error = $state<string | null>(null);
  searchQuery = $state("");
  stagedChanges = $state(new Set<string>());
  groupStagedChanges = $state<Record<string, string>>({});
  profiles = $state<string[]>([]);
  selectedProfile = $state("");

  private DASHBOARD_ACTIONS = new Set([
    "ClearStart", "ClearStartAllUsers", "CreateRestorePoint", "RemoveApps",
    "Apps", "RemoveAppsCustom", "RemoveCommApps", "RemoveW11Outlook",
    "RemoveGamingApps", "RemoveHPApps", "ReplaceStart", "ReplaceStartAllUsers",
    "ForceRemoveEdge", "DeleteTemporaryFiles", "RunDiskCleanup",
    "SystemCorruptionScan", "WinGetReinstall"
  ]);

  constructor() {
    this.refresh();
    if (isTauri) {
      listen("features-config-updated", () => this.refresh());
    }
  }

  async refresh() {
    this.loading = true;
    this.error = null;
    try {
      if (isTauri) {
        this.featuresConfig = await invoke("get_features_config");
        const s = get(settings);
        const auditTargets = (this.featuresConfig?.Features || [])
          .filter((f: any) => !this.DASHBOARD_ACTIONS.has(f.FeatureId))
          .map((f: any) => f.FeatureId);
        
        this.auditResults = await invoke("get_audit_results", { 
          featureIds: auditTargets,
          _offlineHive: s.environmentTarget === "Local Image" ? s.offlineHive : null 
        });
        this.profiles = await invoke("list_tweak_profiles");
      } else {
        // Mock
        this.featuresConfig = {
          Categories: [{ Name: "Essentials", Icon: "" }],
          Features: [{ FeatureId: "Tweak1", Label: "Tweak 1", Category: "Essentials", ToolTip: "Test" }],
          UiGroups: []
        };
        this.auditResults = [{ FeatureId: "Tweak1", Status: "Not Applied" }];
        this.profiles = ["Default.json"];
      }
    } catch (e) {
      this.error = "Sync Failure";
    } finally {
      this.loading = false;
    }
  }

  getStatus(id: string) {
    return this.auditResults.find(r => r.FeatureId === id)?.Status || "Unknown";
  }

  toggleTweak(id: string) {
    if (this.stagedChanges.has(id)) this.stagedChanges.delete(id);
    else this.stagedChanges.add(id);
    this.stagedChanges = new Set(this.stagedChanges);
  }

  toggleGroup(groupId: string, featureId: string) {
    if (!featureId || featureId === "none") delete this.groupStagedChanges[groupId];
    else this.groupStagedChanges[groupId] = featureId;
    this.groupStagedChanges = { ...this.groupStagedChanges };
  }

  async apply() {
    const allIds = [
      ...Array.from(this.stagedChanges),
      ...Object.values(this.groupStagedChanges).filter(id => id && id !== "none")
    ];
    if (allIds.length === 0) return;

    this.loading = true;
    try {
      const s = get(settings);
      const v = get(vhdStore);
      await invoke("apply_features_batch", { 
        featureIds: allIds, 
        offlineHive: s.environmentTarget === 'Local Image' ? "OFFLINE_TEMP" : null,
        targetVm: (s.environmentTarget === 'VHD & VM' && v.remoteActive) ? v.vmName : null
      });
      this.stagedChanges.clear();
      this.groupStagedChanges = {};
      await this.refresh();
      notificationStore.add("Tweaks applied.", "success");
    } catch (e) {
      notificationStore.add(`Failed: ${e}`, "error");
    } finally {
      this.loading = false;
    }
  }

  async loadProfile() {
    if (!this.selectedProfile) return;
    try {
      const p = await invoke("load_tweak_profile", { name: this.selectedProfile }) as any[];
      this.stagedChanges.clear();
      this.groupStagedChanges = {};
      p.forEach(s => {
        if (s.Value === true) this.stagedChanges.add(s.Name);
        else if (typeof s.Value === "string" && s.Value !== "No Change") {
           const group = this.featuresConfig.UiGroups.find((g: any) => g.GroupId === s.Name);
           const val = group?.Values.find((v: any) => v.Label === s.Value);
           if (val) this.groupStagedChanges[group.GroupId] = val.FeatureIds[0];
        }
      });
      this.stagedChanges = new Set(this.stagedChanges);
      this.groupStagedChanges = { ...this.groupStagedChanges };
      notificationStore.add(`Profile "${this.selectedProfile}" loaded.`, 'info');
    } catch (e) { notificationStore.add(`Failed: ${e}`, 'error'); }
  }

  async saveProfile(name?: string) {
    const finalName = name || this.selectedProfile;
    if (!finalName) return;
    const settingsList: any[] = [];
    this.stagedChanges.forEach(id => settingsList.push({ Name: id, Value: true }));
    Object.entries(this.groupStagedChanges).forEach(([gid, fid]) => {
      const group = this.featuresConfig.UiGroups.find((g: any) => g.GroupId === gid);
      const val = group?.Values.find((v: any) => v.FeatureIds.includes(fid));
      if (val) settingsList.push({ Name: gid, Value: val.Label });
    });

    try {
      await invoke("save_tweak_profile", { name: finalName, settings: settingsList });
      this.profiles = await invoke("list_tweak_profiles");
      this.selectedProfile = finalName.endsWith(".json") ? finalName : finalName + ".json";
      notificationStore.add(`Profile "${finalName}" saved.`, 'success');
    } catch (e) { notificationStore.add(`Failed: ${e}`, 'error'); }
  }

  async deleteProfile(name: string) {
    if (!name) return;
    try {
      await invoke("delete_tweak_profile", { name });
      this.profiles = await invoke("list_tweak_profiles");
      if (this.selectedProfile === name) this.selectedProfile = "";
      notificationStore.add(`Profile "${name}" deleted.`, 'info');
    } catch (e) { notificationStore.add(`Failed: ${e}`, 'error'); }
  }
}
