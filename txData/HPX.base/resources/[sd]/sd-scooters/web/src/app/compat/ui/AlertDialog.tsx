import { useEffect, useRef, useState } from 'react';

import { t } from '../i18n';
import { DialogShell } from './DialogShell';
import { portalToPhoneScreen } from './portal';

interface Props {
    title:       string;
    message?:    string;
    confirmLabel?: string;
    cancelLabel?: string;
    destructive?: boolean;
    hideCancel?: boolean;
    forceDark?:  boolean;
    onCancel:    () => void;
    onConfirm:   () => void;
}

interface HostButton { title: string; color?: string; cb?: () => void }
interface HostPopUp { title?: string; description?: string; buttons: HostButton[] }

type OpenPopUp = (buttons: HostButton[], data: Omit<HostPopUp, 'buttons'>) => Promise<number | undefined>;

function hostPopUp(): OpenPopUp | null {
    const w = window as unknown as {
        SetPopUp?: (data: HostPopUp) => Promise<number | undefined>;
        components?: { setPopUp?: (data: HostPopUp) => unknown };
    };
    if (typeof w.SetPopUp === 'function') {
        const open = w.SetPopUp;
        return (buttons, data) => Promise.resolve(open({ ...data, buttons })).then(index => (typeof index === 'number' ? index : undefined));
    }
    const lb = w.components?.setPopUp;
    if (typeof lb === 'function') {
        return (buttons, data) => new Promise(resolve => {
            lb({ ...data, buttons: buttons.map((b, i) => ({ ...b, color: b.color === DESTRUCTIVE ? 'red' : 'blue', cb: () => resolve(i) })) });
        });
    }
    return null;
}

const DESTRUCTIVE = '#FF3B30';

function HostAlert({ open, title, message, confirmLabel, cancelLabel, destructive, hideCancel, onCancel, onConfirm }: Props & { open: OpenPopUp; confirmLabel: string; cancelLabel: string }) {
    const handlers = useRef({ onCancel, onConfirm });
    handlers.current = { onCancel, onConfirm };

    useEffect(() => {
        let settled = false;
        const buttons: HostButton[] = [
            ...(hideCancel ? [] : [{ title: cancelLabel }]),
            { title: confirmLabel, color: destructive ? DESTRUCTIVE : undefined },
        ];
        void open(buttons, { title, description: message }).then(
            index => {
                if (settled) return;
                settled = true;
                if (index === buttons.length - 1) handlers.current.onConfirm();
                else handlers.current.onCancel();
            },
            () => { if (!settled) { settled = true; handlers.current.onCancel(); } },
        );
        return () => { settled = true; };
    }, []);

    return null;
}

function LocalAlert({ title, message, confirmLabel, cancelLabel, destructive = false, hideCancel = false, forceDark = false, onCancel, onConfirm }: Props & { confirmLabel: string; cancelLabel: string }) {
    const [exiting, setExiting] = useState(false);

    useEffect(() => {
        function onKey(e: KeyboardEvent) {
            if (e.key === 'Escape') { e.stopPropagation(); dismiss(onCancel); }
            else if (e.key === 'Enter') { e.stopPropagation(); dismiss(onConfirm); }
        }
        window.addEventListener('keydown', onKey, true);
        return () => window.removeEventListener('keydown', onKey, true);
    }, [onCancel, onConfirm]);

    function dismiss(after: () => void) {
        if (exiting) return;
        setExiting(true);
        window.setTimeout(after, 180);
    }

    return portalToPhoneScreen(
        <DialogShell
            title={title}
            message={message}
            exiting={exiting}
            forceDark={forceDark}
            zIndex={70}
            cancel={hideCancel ? undefined : { label: cancelLabel, onClick: () => dismiss(onCancel) }}
            confirm={{ label: confirmLabel, onClick: () => dismiss(onConfirm), destructive }}
        />,
    );
}

export function AlertDialog(props: Props) {
    const confirmLabel = props.confirmLabel ?? t('common.ok', 'OK');
    const cancelLabel = props.cancelLabel ?? t('common.cancel', 'Cancel');
    const [open] = useState(hostPopUp);
    return open
        ? <HostAlert {...props} open={open} confirmLabel={confirmLabel} cancelLabel={cancelLabel} />
        : <LocalAlert {...props} confirmLabel={confirmLabel} cancelLabel={cancelLabel} />;
}
