import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { getVersion } from '@tauri-apps/api/app';
import { invoke } from '@tauri-apps/api/core';
import { Globe, RefreshCw, FileText, CheckCircle, XCircle, Loader2, Server } from 'lucide-react';
import { openUpdateWindow } from '../utils';
import { getUpdateEndpoint } from '../config/updateSource';
import '../App.css';

function Settings() {
  const { t, i18n } = useTranslation();
  const [appVersion, setAppVersion] = useState('');
  const [checkingUpdate, setCheckingUpdate] = useState(false);
  const [updateStatus, setUpdateStatus] = useState<'idle' | 'available' | 'up-to-date' | 'error'>('idle');
  const [updateError, setUpdateError] = useState('');
  const [autoCheckUpdate, setAutoCheckUpdate] = useState(() => {
    return localStorage.getItem('autoCheckUpdate') === 'true';
  });
  const [lastCheckTime, setLastCheckTime] = useState<string>(() => {
    return localStorage.getItem('lastCheckTime') || '';
  });
  const [logLevel, setLogLevel] = useState(() => {
    return localStorage.getItem('logLevel') || 'info';
  });
  const [updateSource, setUpdateSource] = useState(() => {
    return localStorage.getItem('updateSource') || 'global';
  });

  useEffect(() => {
    getVersion().then(setAppVersion).catch(() => setAppVersion('1.0.0'));
  }, []);

  const handleLanguageChange = (lang: string) => {
    i18n.changeLanguage(lang);
    localStorage.setItem('language', lang);
  };

  const handleAutoCheckChange = (checked: boolean) => {
    setAutoCheckUpdate(checked);
    localStorage.setItem('autoCheckUpdate', String(checked));
  };

  const handleLogLevelChange = (level: string) => {
    setLogLevel(level);
    localStorage.setItem('logLevel', level);
    // Dispatch storage event for other windows
    window.dispatchEvent(new StorageEvent('storage', {
      key: 'logLevel',
      newValue: level
    }));
  };

  const handleUpdateSourceChange = (source: string) => {
    setUpdateSource(source);
    localStorage.setItem('updateSource', source);
  };

  const handleCheckUpdate = async () => {
    setCheckingUpdate(true);
    setUpdateStatus('idle');
    setUpdateError('');

    try {
      const endpoint = getUpdateEndpoint(updateSource as 'global' | 'china');

      const result = await invoke<string | null>('check_update_with_endpoint', { endpoint });

      if (result) {
        const [version, body] = result.split('|');
        await openUpdateWindow(version, body);
      } else {
        setUpdateStatus('up-to-date');
      }
      const now = new Date().toLocaleString();
      setLastCheckTime(now);
      localStorage.setItem('lastCheckTime', now);
    } catch (error) {
      setUpdateStatus('error');
      setUpdateError(String(error));
      const now = new Date().toLocaleString();
      setLastCheckTime(now);
      localStorage.setItem('lastCheckTime', now);
    } finally {
      setCheckingUpdate(false);
    }
  };

  return (
    <div className="settings">
      <div className="settings-section">
        <div className="settings-row">
          <div className="settings-item">
            <Globe size={16} />
            <span>{t('settings.language')}</span>
          </div>
          <div className="settings-control">
            <select 
              value={i18n.language} 
              onChange={(e) => handleLanguageChange(e.target.value)}
              className="language-select"
            >
              <option value="en">English</option>
              <option value="zh">中文</option>
            </select>
          </div>
        </div>

        <div className="settings-divider"></div>

        <div className="settings-row">
          <div className="settings-item">
            <FileText size={16} />
            <span>{t('settings.logLevel')}</span>
          </div>
          <div className="settings-control">
            <select
              value={logLevel}
              onChange={(e) => handleLogLevelChange(e.target.value)}
              className="language-select"
            >
              <option value="debug">Debug</option>
              <option value="info">Info</option>
              <option value="warn">Warn</option>
              <option value="error">Error</option>
            </select>
          </div>
        </div>
        
        <div className="settings-divider"></div>

        <div className="settings-row">
          <div className="settings-item">
            <Server size={16} />
            <span>{t('settings.updateSource')}</span>
          </div>
          <div className="settings-control">
            <select
              value={updateSource}
              onChange={(e) => handleUpdateSourceChange(e.target.value)}
              className="language-select"
              title={t('settings.updateSourceHelp')}
            >
              <option value="global">Global</option>
              <option value="china">China</option>
            </select>
          </div>
        </div>

        <div className="settings-divider"></div>

        <div className="settings-row">
          <div className="settings-item">
            <RefreshCw size={16} />
            <span>{t('settings.autoUpdate')}</span>
          </div>
          <div className="settings-control">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={autoCheckUpdate}
                onChange={(e) => handleAutoCheckChange(e.target.checked)}
              />
              <span></span>
            </label>
          </div>
        </div>

        <div className="settings-divider"></div>

        <div className="settings-center">
          <button 
            className="btn btn-secondary"
            onClick={handleCheckUpdate}
            disabled={checkingUpdate}
          >
            {checkingUpdate ? (
              <Loader2 className="spinning" size={16} />
            ) : (
              <RefreshCw size={16} />
            )}
            <span>{t('settings.checkUpdate')}</span>
          </button>

          {lastCheckTime && (
            <div className="last-check-time">
              {t('settings.lastCheck')}: {lastCheckTime}
            </div>
          )}

          {updateStatus === 'up-to-date' && (
            <div className="update-status">
              <CheckCircle size={16} className="success" />
              <span>{t('settings.upToDate')}</span>
            </div>
          )}

          {updateStatus === 'error' && (
            <div className="update-status error">
              <XCircle size={16} className="error" />
              <span>{t('settings.updateError', { error: updateError })}</span>
            </div>
          )}
        </div>
      </div>

      <div className="settings-version">
        <span>v{appVersion}</span>
        <a href="https://github.com/Qetesh/logi-options-plus-mini" target="_blank" rel="noopener noreferrer">
          GitHub Repo
        </a>
        <span>{t('settings.thirdPartyTool')}</span>
      </div>
    </div>
  );
}

export default Settings;
