import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { check } from '@tauri-apps/plugin-updater';
import { relaunch } from '@tauri-apps/plugin-process';
import { listen } from '@tauri-apps/api/event';
import { getVersion } from '@tauri-apps/api/app';
import { RefreshCw, XCircle, Loader2 } from 'lucide-react';
import '../App.css';

function UpdatePage() {
  const { t } = useTranslation();
  const [version, setVersion] = useState('');
  const [currentVersion, setCurrentVersion] = useState('');
  const [body, setBody] = useState('');
  const [downloading, setDownloading] = useState(false);
  const [updateError, setUpdateError] = useState('');

  useEffect(() => {
    // 获取当前应用版本
    getVersion().then(setCurrentVersion).catch(() => setCurrentVersion('1.0.0'));

    // 优先从 URL 参数获取版本信息
    const params = new URLSearchParams(window.location.search);
    const urlVersion = params.get('version');
    const urlBody = params.get('body');

    if (urlVersion) {
      setVersion(urlVersion);
      setBody(urlBody || '');
    }

    // 监听来自设置窗口的更新通知 (update-info 事件)
    const unlistenUpdateInfo = listen<{ version: string; body: string }>('update-info', (event) => {
      const { version, body } = event.payload;
      setVersion(version);
      setBody(body);
    });

    // 兼容旧的 update-available 事件
    const unlistenUpdateAvailable = listen<{ version: string; body: string }>('update-available', (event) => {
      const { version, body } = event.payload;
      setVersion(version);
      setBody(body);
    });

    return () => {
      unlistenUpdateInfo.then(fn => fn());
      unlistenUpdateAvailable.then(fn => fn());
    };
  }, []);

  const handleDownloadUpdate = async () => {
    setDownloading(true);
    setUpdateError('');
    try {
      console.log('Checking for updates...');
      const update = await check();
      console.log('Update check result:', update);
      
      if (update) {
        console.log('Downloading and installing update...');
        await update.downloadAndInstall();
        console.log('Update downloaded, relaunching...');
        await relaunch();
      } else {
        setUpdateError(t('settings.noUpdateAvailable'));
      }
    } catch (error) {
      console.error('Update error:', error);
      setUpdateError(String(error));
    } finally {
      setDownloading(false);
    }
  };

  return (
    <div className="update-page">
      {/* 第一行：更新图标、应用名称及新版本号 */}
      <div className="update-row update-row-header">
        <RefreshCw size={32} className="update-icon" />
        <div className="update-info">
          <span className="update-app-name">{t('updatePage.updateAvailable')}</span>
          <span className="update-version">{t('updatePage.versionAvailable', { newVersion: version, currentVersion })}</span>
        </div>
      </div>

      {/* 第二行：release note 文本框 */}
      <div className="update-row">
        <div className="update-release-notes">
          {body ? (
            <pre>{body}</pre>
          ) : (
            <span className="update-no-notes">{t('updatePage.noReleaseNotes')}</span>
          )}
        </div>
      </div>

      {/* 第三行：立即更新按钮（居右） */}
      <div className="update-row update-row-footer">
        {updateError && (
          <div className="update-error">
            <XCircle size={14} />
            <span>{updateError}</span>
          </div>
        )}
        <button 
          className="btn btn-primary"
          onClick={handleDownloadUpdate}
          disabled={downloading}
        >
          {downloading ? (
            <Loader2 className="spinning" size={16} />
          ) : (
            <RefreshCw size={16} />
          )}
          <span>{t('updatePage.installUpdate')}</span>
        </button>
      </div>
    </div>
  );
}

export default UpdatePage;
