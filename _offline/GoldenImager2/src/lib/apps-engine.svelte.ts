import { invoke } from "@tauri-apps/api/tauri";
import { notificationStore } from "./notifications";
import { vhdStore, settings } from "./store";
import { get } from "svelte/store";
import type { AppInfo } from "./types";

const isTauri = (window as any).__TAURI_METADATA__ !== undefined;

export class AppsEngine {
  apps = $state<AppInfo[]>([]);
  loading = $state(true);
  error = $state<string | null>(null);
  searchTerm = $state("");
  viewFilter = $state("all");
  selectedProfile = $state("");
  profiles = $state<string[]>([]);
  selectedApps = $state(new Set<string>());
  selectedRisks = $state(new Set(["safe", "warn", "unsafe", "user", "unmapped"]));

  constructor() {
    this.refresh();
  }

  async refresh() {
    this.loading = true;
    this.error = null;
    try {
      if (isTauri) {
        const s = get(settings);
        const isOffline = s.environmentTarget === 'Local Image';
        this.apps = await invoke("get_apps", {
          offlinePath: isOffline ? s.mountPath : null,
          offlineHive: isOffline ? s.offlineHive : null
        });
        this.profiles = await invoke("list_app_profiles");
      } else {
        // Mock data
        this.apps = [
           { AppId: "Microsoft.WindowsCalculator", FriendlyName: "Calc", Recommendation: "safe", IsCurated: true, IsInstalled: true, IsProvisioned: true, IsUser: false },
           { AppId: "Microsoft.YourPhone", FriendlyName: "Phone", Recommendation: "unsafe", IsCurated: true, IsInstalled: true, IsProvisioned: true, IsUser: false }
        ] as AppInfo[];
        this.profiles = ["Default.json"];
      }
    } catch (e) {
      this.error = typeof e === "string" ? e : JSON.stringify(e);
    } finally {
      this.loading = false;
    }
  }

  filteredApps = $derived.by(() => {
    return this.apps.filter((app) => {
      const search = this.searchTerm.toLowerCase();
      const matchesSearch =
        app.FriendlyName?.toLowerCase().includes(search) ||
        app.AppId?.toLowerCase().includes(search);

      let matchesFilter = false;
      switch (this.viewFilter) {
        case "curated": matchesFilter = app.IsCurated; break;
        case "unmapped": matchesFilter = !app.IsCurated; break;
        case "installed": matchesFilter = app.IsInstalled; break;
        case "system": matchesFilter = app.IsProvisioned; break;
        case "user": matchesFilter = app.IsUser; break;
        case "selected": matchesFilter = this.selectedApps.has(app.AppId); break;
        case "all": matchesFilter = true; break;
      }
      
      let effectiveRisk: string;
      if (app.IsUser || app.Recommendation === "user") effectiveRisk = "user";
      else if (app.IsCurated) effectiveRisk = app.Recommendation;
      else effectiveRisk = "unmapped";

      const matchesRisk = this.selectedRisks.has(effectiveRisk);
      return matchesSearch && matchesFilter && matchesRisk;
    });
  });

  toggleSelect(id: string) {
    if (this.selectedApps.has(id)) this.selectedApps.delete(id);
    else this.selectedApps.add(id);
    this.selectedApps = new Set(this.selectedApps);
  }

  toggleSelectAll() {
    const visible = this.filteredApps;
    const allSelected = visible.length > 0 && visible.every(a => this.selectedApps.has(a.AppId));
    if (allSelected) visible.forEach(a => this.selectedApps.delete(a.AppId));
    else visible.forEach(a => this.selectedApps.add(a.AppId));
    this.selectedApps = new Set(this.selectedApps);
  }

  async loadProfile() {
    if (!this.selectedProfile || !isTauri) return;
    try {
      const profileAppIds: string[] = await invoke("load_app_profile", { name: this.selectedProfile });
      const newSelection = new Set<string>();
      
      profileAppIds.forEach(pId => {
        const match = this.apps.find(a => a.AppId.toLowerCase().includes(pId.toLowerCase().split('_')[0]));
        if (match) newSelection.add(match.AppId);
      });

      this.selectedApps = newSelection;
      notificationStore.add(`Profile "${this.selectedProfile}" loaded.`, 'info');
    } catch (e) {
      notificationStore.add(`Load failed: ${e}`, 'error');
    }
  }

  async saveProfile(name?: string) {
    const finalName = name || this.selectedProfile;
    if (!finalName || !isTauri) return;
    const fileName = finalName.endsWith(".json") ? finalName : `${finalName}.json`;
    try {
      await invoke("save_app_profile", {
        name: fileName,
        appIds: Array.from(this.selectedApps),
      });
      this.selectedProfile = fileName;
      this.profiles = await invoke("list_app_profiles");
      notificationStore.add(`Profile "${fileName}" saved.`, 'success');
    } catch (e) {
      notificationStore.add(`Save failed: ${e}`, 'error');
    }
  }

  async deleteProfile(p: string) {
    if (!p || !isTauri) return;
    try {
      await invoke("delete_app_profile", { name: p });
      if (this.selectedProfile === p) this.selectedProfile = "";
      this.profiles = await invoke("list_app_profiles");
      notificationStore.add(`Profile "${p}" deleted.`, 'warning');
    } catch (e) {
      notificationStore.add(`Delete failed: ${e}`, 'error');
    }
  }

  toggleRisk(id: string) {
    if (this.selectedRisks.has(id)) {
      if (this.selectedRisks.size === 1) return;
      this.selectedRisks.delete(id);
    } else this.selectedRisks.add(id);
    this.selectedRisks = new Set(this.selectedRisks);
  }
}
