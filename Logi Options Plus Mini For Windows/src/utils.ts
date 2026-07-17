/**
 * 打开更新窗口
 * @param version 新版本号
 * @param body 更新内容
 */
export async function openUpdateWindow(version: string, body: string): Promise<void> {
  try {
    const { WebviewWindow } = await import('@tauri-apps/api/webviewWindow');
    const isDev = window.location.hostname === 'localhost';
    const url = isDev
      ? `http://localhost:1420/update.html?version=${encodeURIComponent(version)}&body=${encodeURIComponent(body)}`
      : `update.html?version=${encodeURIComponent(version)}&body=${encodeURIComponent(body)}`;

    const existing = await WebviewWindow.getByLabel('update');
    if (existing) {
      await existing.show();
      await existing.setFocus();
      // 发射事件传递数据
      await existing.emit('update-info', { version, body });
      return;
    }

    new WebviewWindow('update', {
      url: url,
      title: 'Update',
      width: 500,
      height: 300,
      resizable: false,
      center: true,
    });
  } catch (err) {
    console.error('Error opening update window:', err);
  }
}
