import { invoke } from '@tauri-apps/api/core';
import type { FeatureInfo, VersionInfo, InstallResult } from './types';

export async function getFeatures(): Promise<FeatureInfo[]> {
  return invoke<FeatureInfo[]>('get_features');
}

export async function getInstalledVersion(): Promise<string> {
  return invoke<string>('get_installed_version');
}

export async function getLatestVersion(): Promise<string> {
  return invoke<string>('get_latest_version');
}

export async function getVersionInfo(): Promise<VersionInfo> {
  return invoke<VersionInfo>('get_version_info');
}

export async function install(selectedFeatures: [string, boolean][], source?: string): Promise<InstallResult> {
  return invoke<InstallResult>('install', { selectedFeatures, source: source ?? null });
}

export async function uninstall(source?: string): Promise<InstallResult> {
  return invoke<InstallResult>('uninstall', { source: source ?? null });
}

export async function installOffline(selectedFeatures: [string, boolean][], source?: string): Promise<InstallResult> {
  return invoke<InstallResult>('install_offline', { selectedFeatures, source: source ?? null });
}
