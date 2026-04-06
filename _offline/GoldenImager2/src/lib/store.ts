import { writable, derived } from 'svelte/store';

export interface SystemSettings {
  accentColor: string;
  riskyThreshold: number;
  glassOpacity: number;
  autoScan: boolean;
  enforcePolicy: boolean;
  logRetention: number;
  matchVersioning: boolean;
  curatedOnly: boolean;
  parallelAudit: boolean;
  showNotifications: boolean;
  windowWidth: number;
  windowHeight: number;
  windowX: number;
  windowY: number;
  retainWindowState: boolean;
  environmentTarget: 'Local Image' | 'VHD & VM' | 'Local';
  mountPath: string;
  offlineHive: string;
}

const DEFAULT_SETTINGS: SystemSettings = {
  accentColor: "#4fb995",
  riskyThreshold: 3,
  glassOpacity: 10,
  autoScan: true,
  enforcePolicy: false,
  logRetention: 30,
  matchVersioning: true,
  curatedOnly: false,
  parallelAudit: true,
  showNotifications: true,
  windowWidth: 895,
  windowHeight: 1195,
  windowX: 100,
  windowY: 100,
  retainWindowState: false,
  environmentTarget: 'Local Image',
  mountPath: "P:/Projects/golden-image/_offline_host/mount",
  offlineHive: "OFFLINE_TEMP"
};

// Load initial settings from localStorage if available
const storedSettings = localStorage.getItem('golden-imager-settings');
const initialSettings = storedSettings 
  ? { ...DEFAULT_SETTINGS, ...JSON.parse(storedSettings) } 
  : DEFAULT_SETTINGS;

export const settings = writable<SystemSettings>(initialSettings);

// Persist settings on change
settings.subscribe(value => {
  localStorage.setItem('golden-imager-settings', JSON.stringify(value));
});

// Derived RGB string for CSS variables
export const accentRgb = derived(settings, $s => {
  const hex = $s.accentColor.replace('#', '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  return `${r}, ${g}, ${b}`;
});

// VHD/VM GLOBAL CONTEXT
export interface VhdState {
  vhdPath: string;
  vmName: string;
  vhdMounted: boolean;
  vhdAttached: boolean;
  vhdDiskNumber: number | null;
  processing: boolean;
  selectedProfile: string;
  remoteActive: boolean;
}

const DEFAULT_VHD_STATE: VhdState = {
  vhdPath: "",
  vmName: "",
  vhdMounted: false,
  vhdAttached: false,
  vhdDiskNumber: null,
  processing: false,
  selectedProfile: "",
  remoteActive: false
};

export const vhdStore = writable<VhdState>(DEFAULT_VHD_STATE);
