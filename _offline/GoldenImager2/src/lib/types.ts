export interface AppInfo {
  AppId: string;
  FriendlyName: string;
  Recommendation: 'safe' | 'warn' | 'unsafe' | 'user' | 'unmapped';
  Publisher?: string;
  OriginType?: string;
  IsCurated: boolean;
  IsInstalled: boolean;
  IsProvisioned: boolean;
  IsUser: boolean;
  Status?: string;
}

export interface TweakInfo {
  id: string;
  label: string;
  description: string;
  category: string;
  applied: boolean;
  risk: 'safe' | 'warn' | 'unsafe';
  requiresRestart?: boolean;
}
