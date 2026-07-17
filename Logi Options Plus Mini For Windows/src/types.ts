export interface FeatureInfo {
  id: string;
  name: string;
  description: string;
  // help?: string;
  default_enabled: boolean;
}

export interface VersionInfo {
  installed_version: string;
  latest_version: string;
}

export interface InstallResult {
  success: boolean;
  message: string;
  version: string | null;
}

export type InstallStep = 
  | 'idle' 
  | 'downloading' 
  | 'extracting'
  | 'backup'
  | 'uninstalling'
  | 'restoring'
  | 'installing'
  | 'completed'
  | 'failed';

export interface LogMessage {
  id: string;
  content: string;
  timestamp: Date;
}
