// 更新源配置
export const UPDATE_SOURCES = {
  auto: {
    name: 'Auto',
    endpoint: null, // 复用后端区域检测逻辑，自动选择 China 或默认源
  },
  global: {
    name: 'Global',
    endpoint: "https://raw.githubusercontent.com/Qetesh/logi-options-plus-mini/refs/heads/main/latest.json", // 使用系统默认（GitHub）
  },
  china: {
    name: 'China',
    endpoint: 'https://v.qetesh.cc/d/Public/latest.json',
  },
} as const;

export type UpdateSourceKey = keyof typeof UPDATE_SOURCES;

export const DEFAULT_UPDATE_SOURCE: UpdateSourceKey = 'auto';

export const getUpdateEndpoint = (source: UpdateSourceKey): string | null => {
  return UPDATE_SOURCES[source].endpoint;
};
