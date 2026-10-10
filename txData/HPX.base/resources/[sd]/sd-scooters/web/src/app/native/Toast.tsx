import { useEffect, useRef, useState } from 'react';
import { Check } from 'lucide-react';

import { portalToPhoneScreen } from '../compat/ui/portal';

const ACCENT = '#14b8a6';

export function Toast({ message, onDone, duration = 2400 }: { message: string; onDone: () => void; duration?: number }) {
    const [exiting, setExiting] = useState(false);
    const finish = useRef(onDone);
    finish.current = onDone;

    useEffect(() => {
        setExiting(false);
        const leave = window.setTimeout(() => setExiting(true), duration);
        const done = window.setTimeout(() => finish.current(), duration + 240);
        return () => { window.clearTimeout(leave); window.clearTimeout(done); };
    }, [message, duration]);

    return portalToPhoneScreen(
        <div
            className="pointer-events-none absolute inset-x-0 flex justify-center px-6"
            style={{ bottom: 'calc(var(--safe-bottom) + 96px)', zIndex: 80 }}
        >
            <div
                key={message}
                className="flex max-w-full items-center gap-2.5 rounded-full bg-black/85 px-4 py-2.5 text-[15px] font-semibold text-white shadow-[0_14px_36px_-12px_rgba(0,0,0,0.7)] backdrop-blur-xl dark:bg-white/95 dark:text-black"
                style={{ animation: exiting ? 'scoot-toast-out 220ms cubic-bezier(0.32,0,0.68,1) forwards' : 'scoot-toast-in 320ms cubic-bezier(0.32,0.72,0,1)' }}
            >
                <span className="flex h-[20px] w-[20px] shrink-0 items-center justify-center rounded-full" style={{ background: ACCENT }}>
                    <Check className="h-[13px] w-[13px] text-white" strokeWidth={3} />
                </span>
                <span className="truncate">{message}</span>
            </div>
        </div>,
    );
}
