import { createElement } from 'react';
import { createPortal } from 'react-dom';
import type { ReactNode } from 'react';

export function portalToPhoneScreen(node: ReactNode): ReactNode {
    const root = typeof document !== 'undefined'
        ? (document.querySelector('[data-phone-screen]') as HTMLElement | null)
        : null;
    if (!root) return node;
    return createPortal(
        createElement('div', { 'data-motion-app': '1', style: { display: 'contents' } }, node),
        root,
    );
}
