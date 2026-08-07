/**
 * 打开更新窗口
 * @param version 新版本号
 * @param body 更新内容
 * @param source 更新源（'global' | 'china'），用于安装时复用同一 endpoint
 */
export async function openUpdateWindow(version: string, body: string, source?: string): Promise<void> {
  try {
    const { WebviewWindow } = await import('@tauri-apps/api/webviewWindow');
    const query = new URLSearchParams({ version, body });
    if (source) {
      query.set('source', source);
    }
    const url = `update.html?${query.toString()}`;

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
