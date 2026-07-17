import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './locales/en.json';
import zh from './locales/zh.json';

// 获取系统语言
const getSystemLanguage = (): string => {
  const lang = navigator.language || 'en';
  // 简单处理：如果是中文环境，默认使用中文
  if (lang.startsWith('zh')) {
    return 'zh';
  }
  return 'en';
};

// 从 localStorage 获取保存的语言设置，如果没有则使用系统语言
const getSavedLanguage = (): string => {
  const saved = localStorage.getItem('language');
  if (saved && (saved === 'en' || saved === 'zh')) {
    return saved;
  }
  return getSystemLanguage();
};

i18n
  .use(initReactI18next)
  .init({
    resources: {
      en: { translation: en },
      zh: { translation: zh }
    },
    lng: getSavedLanguage(),
    fallbackLng: 'en',
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;
