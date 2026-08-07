import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { relaunch } from '@tauri-apps/plugin-process';
import { listen } from '@tauri-apps/api/event';
import { invoke } from '@tauri-apps/api/core';
import { getVersion } from '@tauri-apps/api/app';
import { RefreshCw, XCircle, Loader2 } from 'lucide-react';
import { getUpdateEndpoint } from '../config/updateSource';
import '../App.css';

type UpdateStatus = 'idle' | 'downloading' | 'installing' | 'done' | 'error';

function UpdatePage() {
  const { t } = useTranslation();
  const [version, setVersion] = useState('');
  const [currentVersion, setCurrentVersion] = useState('');
  const [body, setBody] = useState('');
  const [downloading, setDownloading] = useState(false);
  const [updateError, setUpdateError] = useState('');
  const [status, setStatus] = useState<UpdateStatus>('idle');
  const [progress, setProgress] = useState<{ downloaded: number; total: number }>({
    downloaded: 0,
    total: 0,
  });

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

    // 监听后端下载/安装进度
    const unlistenProgress = listen<{ downloaded: number; total: number }>(
      'update-progress',
      (event) => {
        setProgress({ downloaded: event.payload.downloaded, total: event.payload.total });
      }
    );

    const unlistenStatus = listen<{ status: string; version?: string }>('update-status', (event) => {
      if (event.payload.status === 'downloading') {
        setStatus('downloading');
      } else if (event.payload.status === 'installing') {
        setStatus('installing');
      }
    });

    return () => {
      unlistenUpdateInfo.then(fn => fn());
      unlistenUpdateAvailable.then(fn => fn());
      unlistenProgress.then(fn => fn());
      unlistenStatus.then(fn => fn());
    };
  }, []);

  const handleDownloadUpdate = async () => {
    setDownloading(true);
    setUpdateError('');
    setStatus('idle');
    setProgress({ downloaded: 0, total: 0 });
    try {
      const params = new URLSearchParams(window.location.search);
      // 优先使用窗口打开时传入的 source，回退到 localStorage 中的设置
      const source = params.get('source') || localStorage.getItem('updateSource') || 'auto';
      const endpoint = getUpdateEndpoint(source as 'auto' | 'global' | 'china');

      console.log('[Update] Start update. source =', source, 'endpoint =', endpoint);

      // 使用与“检查更新”相同的 endpoint 执行下载安装，
      // 避免使用默认的 GitHub endpoint 导致“检查到更新却安装时提示没有可用更新”。
      await invoke('download_and_install_with_endpoint', { source, endpoint });
      console.log('[Update] Download + install finished, relaunching...');
      setStatus('done');
      await relaunch();
    } catch (error) {
      console.error('[Update] Update error:', error);
      const errStr = String(error);
      // 后端在确实没有可用更新时返回此错误码
      if (errStr.includes('no_update_available')) {
        setUpdateError(t('settings.noUpdateAvailable'));
      } else {
        setUpdateError(errStr);
      }
      setStatus('error');
    } finally {
      setDownloading(false);
    }
  };

  const progressPercent =
    progress.total > 0 ? Math.floor((progress.downloaded / progress.total) * 100) : 0;

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

      {/* 下载进度条 */}
      {status === 'downloading' && progress.total > 0 && (
        <div className="update-row">
          <div className="update-progress-bar">
            <div className="update-progress-fill" style={{ width: `${progressPercent}%` }} />
          </div>
          <span className="update-progress-text">{progressPercent}%</span>
        </div>
      )}
      {status === 'installing' && (
        <div className="update-row">
          <span className="update-status-text">{t('updatePage.installingUpdate')}</span>
        </div>
      )}

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
          <span>
            {status === 'downloading'
              ? t('updatePage.downloadingUpdate')
              : status === 'installing'
                ? t('updatePage.installingUpdate')
                : t('updatePage.installUpdate')}
          </span>
        </button>
      </div>
    </div>
  );
}

export default UpdatePage;
