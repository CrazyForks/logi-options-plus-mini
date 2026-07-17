// 更新源配置
export const UPDATE_SOURCES = {
  global: {
    name: 'Global',
    endpoint: null, // 使用系统默认
  },
  china: {
    name: 'China',
    endpoint: 'https://v.qetesh.cc/d/Public/latest.json',
  },
} as const;

export type UpdateSourceKey = keyof typeof UPDATE_SOURCES;

export const getUpdateEndpoint = (source: UpdateSourceKey): string | null => {
  return UPDATE_SOURCES[source].endpoint;
};
