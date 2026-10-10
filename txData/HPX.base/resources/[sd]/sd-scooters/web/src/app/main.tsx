import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Scoot } from './native/Scoot';
import '@fontsource/inter/latin-400.css';
import '@fontsource/inter/latin-500.css';
import '@fontsource/inter/latin-600.css';
import '@fontsource/inter/latin-700.css';
import '@fontsource/inter/latin-800.css';
import '@fontsource/inter/latin-900.css';
import './app.css';

declare global {
  interface Window {
    invokeNative?: unknown;
    resourceName?: string;
    fetchNui?: <T = unknown>(event: string, data?: unknown) => Promise<T | undefined>;
    GetPhoneNumber?: () => Promise<string | null>;
    SendNotification?: (data: { title?: string; content?: string; thumbnail?: string }) => Promise<null>;
    ShowConfirm?: (data: { title?: string; description?: string; confirmText?: string; cancelText?: string; color?: string }) => Promise<boolean>;
    OnSettingsChange?: (cb: (s: { theme: 'light' | 'dark' }) => void) => void;
  }
}

const devMode = typeof window.invokeNative === 'undefined';

let rendered = false;

function render() {
  if (rendered) return;
  rendered = true;
  document.body.style.visibility = 'visible';
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <Scoot />
    </StrictMode>,
  );
}

if (devMode) {
  document.body.dataset.theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  render();
} else if (window.parent !== window) {
  window.addEventListener('message', e => {
    if (e.data === 'componentsLoaded') render();
  });
}
