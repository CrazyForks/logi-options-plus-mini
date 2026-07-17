import { useState, useEffect, useCallback, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { 
  Download, 
  Trash2, 
  CheckCircle, 
  XCircle,
  Info,
  ChevronDown,
  ChevronUp,
  Loader2,
  Settings
} from 'lucide-react';
import { listen } from '@tauri-apps/api/event';
import { invoke } from '@tauri-apps/api/core';
import { openUpdateWindow } from './utils';
import { getUpdateEndpoint } from './config/updateSource';
import { getVersionInfo, getInstalledVersion, getLatestVersion, install, uninstall } from './api';
import type { FeatureInfo, VersionInfo, InstallStep } from './types';
import './App.css';

// 静态 features 数据，与 Rust 后端保持一致，作为初始值避免加载空白
const DEFAULT_FEATURES: FeatureInfo[] = [
  { id: 'quiet', name: 'Quiet Install', description: 'Quiet Install', default_enabled: false },
  { id: 'analytics', name: 'Analytics', description: 'Analytics', default_enabled: false },
  { id: 'flow', name: 'Flow', description: 'Flow', default_enabled: false },
  { id: 'sso', name: 'SSO', description: 'SSO', default_enabled: false },
  { id: 'update', name: 'Update', description: 'Update', default_enabled: false },
  { id: 'dfu', name: 'DFU', description: 'DFU', default_enabled: false },
  { id: 'backlight', name: 'Backlight', description: 'Backlight', default_enabled: false },
  { id: 'logivoice', name: 'LogiVoice', description: 'LogiVoice', default_enabled: false },
  { id: 'aipromptbuilder', name: 'AI Prompt Builder', description: 'AI Prompt Builder', default_enabled: false },
  { id: 'device-recommendation', name: 'Device Recommendation', description: 'Device Recommendation', default_enabled: false },
  { id: 'smartactions', name: 'Smart Actions', description: 'Smart Actions', default_enabled: false },
  { id: 'actions-ring', name: 'Actions Ring', description: 'Actions Ring', default_enabled: false },
];

function App() {
  const { t, i18n } = useTranslation();
  const initialized = useRef(false);
  const initialLoadComplete = useRef(false);
  const [features] = useState<FeatureInfo[]>(DEFAULT_FEATURES);
  const [selectedFeatures, setSelectedFeatures] = useState<Set<string>>(new Set());
  const [versionInfo, setVersionInfo] = useState<VersionInfo>({ installed_version: '', latest_version: '' });
  const [currentStep, setCurrentStep] = useState<InstallStep>('idle');
  const [isLoading, setIsLoading] = useState(false);
  const [showActivityLog, setShowActivityLog] = useState(false);
  const [logs, setLogs] = useState<{ message: string; level: string }[]>([]);
  const [logLevel, setLogLevel] = useState<string>(() => {
    return localStorage.getItem('logLevel') || 'info';
  });
  const [refreshingInstalled, setRefreshingInstalled] = useState(false);
  const [refreshingLatest, setRefreshingLatest] = useState(false);

  const addLog = useCallback((message: string, level: string = 'info') => {
    const timestamp = new Date().toLocaleTimeString();
    // Ensure level is always a valid string, default to 'info'
    const validLevel = level || 'info';
    // Check for i18n prefix and translate
    let displayMessage = message;
    if (message.startsWith('i18n:')) {
      const key = message.substring(5);
      displayMessage = t(key);
    }
    setLogs(prev => [...prev, { message: `[${timestamp}] ${displayMessage}`, level: validLevel }]);
  }, [t]);

  // 自动滚动日志到底部的 ref
  const logContentRef = useRef<HTMLDivElement>(null);

  // 监听 localStorage 变化（设置页切换语言时触发），强制重新渲染
  useEffect(() => {
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === 'language' && e.newValue) {
        i18n.changeLanguage(e.newValue);
      }
      if (e.key === 'logLevel' && e.newValue) {
        setLogLevel(e.newValue);
      }
    };
    window.addEventListener('storage', handleStorageChange);
    return () => {
      window.removeEventListener('storage', handleStorageChange);
    };
  }, [i18n]);

  // 当日志更新时自动滚动到底部
  useEffect(() => {
    if (logContentRef.current) {
      logContentRef.current.scrollTop = logContentRef.current.scrollHeight;
    }
  }, [logs]);

  // Filter logs based on log level
  // Priority: higher number = more severe, lower number = less severe
  // When user selects a level, show all logs with priority >= selected level
  // Default to 0 so unknown levels show all logs
  const getLogLevelPriority = (level: string | undefined): number => {
    if (!level) return 0;
    switch (level) {
      case 'error': return 4;
      case 'warn': return 3;
      case 'info': return 2;
      case 'debug': return 1;
      default: return 0;
    }
  };

  const filteredLogs = logs.filter(log => {
    const priority = getLogLevelPriority(logLevel);
    const logPriority = getLogLevelPriority(log.level);
    return logPriority >= priority;
  });

  // Update step based on log messages from backend
  const updateStepFromLog = useCallback((message: string) => {
    if (message.includes('Step 1/5: Downloading') || message.includes('Downloading installer')) {
      setCurrentStep('downloading');
    } else if (message.includes('Step 2/5: Backing up') || message.includes('Backing up configuration')) {
      setCurrentStep('backup');
    } else if (message.includes('Step 3/5: Uninstalling') || message.includes('Uninstalling')) {
      setCurrentStep('uninstalling');
    } else if (message.includes('Step 4/5: Restoring') || message.includes('Restoring configuration')) {
      setCurrentStep('restoring');
    } else if (message.includes('Step 5/5: Installing') || message.includes('Installing new version')) {
      setCurrentStep('installing');
    } else if (message.includes('completed successfully')) {
      setCurrentStep('completed');
    } else if (message.includes('failed') || message.includes('Failed')) {
      setCurrentStep('failed');
    }
  }, []);

  // Listen for log messages from backend
  useEffect(() => {
    const unlisten = listen<{ message: string; level: string }>('log-message', (event) => {
      addLog(event.payload.message, event.payload.level || 'info');
      updateStepFromLog(event.payload.message);
    });

    return () => {
      unlisten.then(fn => fn());
    };
  }, [addLog, updateStepFromLog]);

  // Load features on mount
  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;

    async function loadData() {
      try {
        // features 已使用静态初始值，无需从后端获取
        // 只获取版本信息（需要网络请求）
        const versionData = await getVersionInfo();
        setVersionInfo(versionData);

        // Load saved preferences from localStorage first (user's saved choice takes priority)
        const saved = localStorage.getItem('selectedFeatures');
        let loadedFromStorage = false;
        if (saved) {
          try {
            const parsed = JSON.parse(saved);
            setSelectedFeatures(new Set(parsed));
            loadedFromStorage = true;
          } catch (e) {
            console.error('Failed to parse saved features:', e);
          }
        }

        // Only set defaults if nothing was saved in localStorage
        if (!loadedFromStorage) {
          const defaults = new Set<string>();
          DEFAULT_FEATURES.forEach(f => {
            if (f.default_enabled) {
              defaults.add(f.id);
            }
          });
          setSelectedFeatures(defaults);
        }

        // Mark initial load as complete (so useEffect won't save defaults to localStorage)
        initialLoadComplete.current = true;

        addLog(t('logs.initialized'));
      } catch (error) {
        addLog(t('logs.errorLoadingData', { error }));
      }
    }

    loadData();
  }, [addLog]);

  // 启动时自动检查更新（后台进行，不阻塞UI）
  useEffect(() => {
    const autoCheckUpdate = localStorage.getItem('autoCheckUpdate') === 'true';
    if (!autoCheckUpdate) return;

    // 延迟一下再检查，确保应用完全加载
    const timer = setTimeout(async () => {
      try {
        const updateSource = (localStorage.getItem('updateSource') || 'global') as 'global' | 'china';
        const endpoint = getUpdateEndpoint(updateSource);

        const result = await invoke<string | null>('check_update_with_endpoint', { endpoint });

        if (result) {
          const [version, body] = result.split('|');
          await openUpdateWindow(version, body);
        }
      } catch (error) {
        console.error('Auto check update failed:', error);
      }
    }, 2000);

    return () => clearTimeout(timer);
  }, []);

  // Save selected features to localStorage (only after initial load is complete)
  useEffect(() => {
    if (initialLoadComplete.current) {
      localStorage.setItem('selectedFeatures', JSON.stringify([...selectedFeatures]));
    }
  }, [selectedFeatures]);

  const handleFeatureToggle = (featureId: string) => {
    setSelectedFeatures(prev => {
      const newSet = new Set(prev);
      if (newSet.has(featureId)) {
        newSet.delete(featureId);
      } else {
        newSet.add(featureId);
      }
      return newSet;
    });
  };

  const handleInstall = async () => {
    setIsLoading(true);
    addLog(t('logs.installing'));
    
    // 如果当前是 completed 或 failed，先重置到 idle (0%)，延迟后再开始
    if (currentStep === 'completed' || currentStep === 'failed') {
      setCurrentStep('idle');
      // 等待进度条动画到 0% 后再开始安装
      setTimeout(async () => {
        setCurrentStep('downloading');
        await performInstall();
      }, 300);
      return;
    }
    
    // 正常开始安装流程
    setCurrentStep('idle');
    setTimeout(() => {
      setCurrentStep('downloading');
      performInstall();
    }, 100);
  };

  // 实际执行安装的逻辑
  const performInstall = async () => {
    try {
      const featureArray: [string, boolean][] = features.map(f => [f.id, selectedFeatures.has(f.id)]);
      addLog(`Features: ${featureArray.map(([k, v]) => `${k}:${v}`).join(' ')}`);
      
      // 步骤会由后端日志消息自动更新
      const result = await install(featureArray);
      
      if (result.success) {
        setCurrentStep('completed');
        addLog(t('logs.installSuccess'));
        addLog(t('logs.installVersion', { version: result.version }));
        
        // Refresh version info
        const newVersionInfo = await getVersionInfo();
        setVersionInfo(newVersionInfo);
      } else {
        setCurrentStep('failed');
        addLog(t('logs.installFailed', { message: result.message }));
      }
    } catch (error) {
      setCurrentStep('failed');
      addLog(t('logs.error', { error }));
    } finally {
      setIsLoading(false);
    }
  };

  const handleUninstall = async () => {
    setIsLoading(true);
    addLog(t('logs.uninstalling'));
    
    // 如果当前是 completed 或 failed，先重置到 idle (0%)，延迟后再开始
    if (currentStep === 'completed' || currentStep === 'failed') {
      setCurrentStep('idle');
      // 等待进度条动画到 0% 后再开始卸载
      setTimeout(async () => {
        setCurrentStep('uninstalling');
        await performUninstall();
      }, 300);
      return;
    }
    
    // 正常开始卸载流程
    setCurrentStep('idle');
    setTimeout(() => {
      setCurrentStep('uninstalling');
      performUninstall();
    }, 100);
  };

  // 实际执行卸载的逻辑
  const performUninstall = async () => {
    try {
      const result = await uninstall();
      
      if (result.success) {
        setCurrentStep('completed');
        addLog(t('logs.uninstallSuccess'));
        
        // Refresh version info after uninstall (with small delay to ensure registry is updated)
        await new Promise(resolve => setTimeout(resolve, 2000));
        const newVersionInfo = await getVersionInfo();
        setVersionInfo(newVersionInfo);
        
        // Show appropriate message based on uninstall result
        if (newVersionInfo.installed_version === 'not installed' || newVersionInfo.installed_version === t('version.notInstalled')) {
          addLog(t('logs.uninstallNoteRemoved'));
        } else {
          addLog(t('logs.uninstallNoteStillInstalled', { version: newVersionInfo.installed_version }));
        }
      } else {
        setCurrentStep('failed');
        addLog(t('logs.uninstallFailed', { message: result.message }));
      }
    } catch (error) {
      setCurrentStep('failed');
      addLog(t('logs.error', { error }));
    } finally {
      setIsLoading(false);
    }
  };

  const refreshInstalledVersion = async () => {
    if (refreshingInstalled) return;
    setRefreshingInstalled(true);
    
    // 显示旋转动画
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
      const installed = await getInstalledVersion();
      setVersionInfo(prev => ({ ...prev, installed_version: installed }));
      addLog(t('logs.refreshedInstalled'));
    } catch (error) {
      addLog(t('logs.refreshFailedInstalled', { error }));
    } finally {
      setRefreshingInstalled(false);
    }
  };

  const refreshLatestVersion = async () => {
    if (refreshingLatest) return;
    setRefreshingLatest(true);
    
    // 显示旋转动画
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
      const latest = await getLatestVersion();
      setVersionInfo(prev => ({ ...prev, latest_version: latest }));
      addLog(t('logs.refreshedLatest'));
    } catch (error) {
      addLog(t('logs.refreshFailedLatest', { error }));
    } finally {
      setRefreshingLatest(false);
    }
  };

  // 6个步骤：下载 -> 备份配置 -> 卸载 -> 恢复配置 -> 安装 -> 完成
  const getStepProgress = (): number => {
    switch (currentStep) {
      case 'idle': return 0;
      case 'downloading':
      case 'extracting': return 17;       // 第1步: 下载 (0-17%)
      case 'backup': return 33;           // 第2步: 备份配置 (17-33%)
      case 'uninstalling': return 50;     // 第3步: 卸载 (33-50%)
      case 'restoring': return 67;        // 第4步: 恢复配置 (50-67%)
      case 'installing': return 83;       // 第5步: 安装 (67-83%)
      case 'completed': return 100;       // 第6步: 完成 (100%)
      case 'failed': return 100;
      default: return 0;
    }
  };

  const getStepText = (): string => {
    switch (currentStep) {
      case 'idle': return t('progress.idle');
      case 'downloading': return t('progress.downloading');
      case 'extracting': return t('progress.extracting');
      case 'backup': return t('progress.backup');
      case 'uninstalling': return t('progress.uninstalling');
      case 'restoring': return t('progress.restoring');
      case 'installing': return t('progress.installing');
      case 'completed': return t('progress.completed');
      case 'failed': return t('progress.failed');
      default: return currentStep;
    }
  };

  const getStepIcon = () => {
    switch (currentStep) {
      case 'completed': return <CheckCircle className="step-icon success" size={16} />;
      case 'failed': return <XCircle className="step-icon error" size={16} />;
      case 'idle': return <Info className="step-icon" size={16} />;
      default: return <Loader2 className="step-icon spinning" size={16} />;
    }
  };

  return (
    <div className="app">
      <div className="main-content">
        <div className="header-row">
          <h2>{t('features.title')}</h2>
          <button 
            className="language-toggle"
            onClick={async () => {
              console.log('Settings button clicked');
              try {
                const { WebviewWindow } = await import('@tauri-apps/api/webviewWindow');
                // Check if window already exists
                const existing = await WebviewWindow.getByLabel('settings');
                if (existing) {
                  await existing.show();
                  await existing.setFocus();
                  return;
                }
                // Use different URL for dev vs prod
                const isDev = window.location.hostname === 'localhost';
                const url = isDev ? 'http://localhost:1420/settings.html' : 'settings.html';
                console.log('Creating settings window with URL:', url);
                // Create new window
                const webview = new WebviewWindow('settings', {
                  url: url,
                  title: 'Settings',
                  width: 400,
                  height: 380,
                  resizable: false,
                  center: true,
                });
                webview.once('tauri://created', () => {
                  console.log('Settings window created');
                });
                webview.once('tauri://error', (e) => {
                  console.error('Error creating settings window:', e);
                });
              } catch (err) {
                console.error('Error:', err);
              }
            }}
            title={t('settings.title')}
          >
            <Settings size={16} />
          </button>
        </div>
        
        <div className="feature-list">
          {features.map((feature) => (
            <div
              key={feature.id}
              className="feature-item"
              title={t(`features.${feature.id}`)}
            >
              <label className="feature-label">
                <input
                  type="checkbox"
                  checked={selectedFeatures.has(feature.id)}
                  onChange={() => handleFeatureToggle(feature.id)}
                  disabled={isLoading}
                />
                <span className="feature-name">{feature.name}</span>
              </label>
            </div>
          ))}
        </div>

        <div className="version-actions-row">
          <div className="version-info">
            <div className="version-row">
              <span 
                className="version-text clickable"
                onClick={refreshInstalledVersion}
                title={t('version.refreshInstalled')}
              >
                {t('version.installed')} {refreshingInstalled ? (
                  <Loader2 className="spinning" size={14} />
                ) : (versionInfo.installed_version === 'not installed' ? t('version.notInstalled') : (versionInfo.installed_version || t('version.loading')))}
              </span>
            </div>
            {versionInfo.latest_version && versionInfo.latest_version !== 'Unknown' && (
              <div className="version-row">
                <span 
                  className="version-text clickable"
                  onClick={refreshLatestVersion}
                  title={t('version.refreshLatest')}
                >
                  {t('version.latest')} {refreshingLatest ? (
                    <Loader2 className="spinning" size={14} />
                  ) : versionInfo.latest_version}
                </span>
              </div>
            )}
          </div>

          <div className="action-buttons">
          <button 
            className="btn btn-primary"
            onClick={handleInstall}
            disabled={isLoading}
          >
            {isLoading && currentStep !== 'idle' ? (
              <Loader2 className="spinning" size={16} />
            ) : (
              <Download size={16} />
            )}
            <span>{t('buttons.install')}</span>
          </button>

          {versionInfo.installed_version && versionInfo.installed_version !== 'not installed' && versionInfo.installed_version !== t('version.notInstalled') && (
            <button 
              className="btn btn-danger"
              onClick={handleUninstall}
              disabled={isLoading}
            >
              <Trash2 size={16} />
              <span>{t('buttons.uninstall')}</span>
            </button>
          )}

        </div>
        </div>

        {!showActivityLog && (
          <div className="progress-section">
            <div className="progress-header">
              <div className="progress-info">
                {getStepIcon()}
                <span className="progress-text">{getStepText()}</span>
              </div>
              <button 
                className="log-toggle"
                onClick={() => setShowActivityLog(!showActivityLog)}
              >
                {showActivityLog ? <ChevronDown size={16} /> : <ChevronUp size={16} />}
                <span>{showActivityLog ? t('log.hide') : t('log.view')}</span>
              </button>
            </div>
            
            {/* 进度条在所有状态下都显示 */}
            <div className={`progress-bar ${currentStep === 'completed' ? 'success' : currentStep === 'failed' ? 'error' : ''}`}>
              <div 
                className="progress-fill"
                style={{ width: `${getStepProgress()}%` }}
              />
            </div>
          </div>
        )}

        {showActivityLog && (
          <div className="activity-log">
            <div className="log-header">
              <span>{t('log.title')}</span>
              <div className="log-header-actions">
                <button onClick={() => setLogs([])}>{t('log.clear')}</button>
                <button onClick={() => setShowActivityLog(false)}>{t('log.hide')}</button>
              </div>
            </div>
            <div className="log-content" ref={logContentRef}>
              {filteredLogs.map((log, index) => (
                <div key={index} className={`log-message log-level-${log.level}`}>
                  <span className="log-level-badge">{log.level.toUpperCase()}</span>
                  {log.message}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
