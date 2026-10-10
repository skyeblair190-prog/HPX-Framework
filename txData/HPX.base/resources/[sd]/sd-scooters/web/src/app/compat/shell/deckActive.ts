import { useEffect, useState } from 'react';

type Unsubscribe = (() => void) | undefined;
type Watch = (cb: () => void) => Unsubscribe;

export function useDeckActive(): boolean {
    const [active, setActive] = useState(() => typeof document === 'undefined' || !document.hidden);

    useEffect(() => {
        const host = window as unknown as { OnAppOpen?: Watch; OnAppClose?: Watch };
        const stops: Unsubscribe[] = [];
        if (typeof host.OnAppOpen === 'function') stops.push(host.OnAppOpen(() => setActive(true)));
        if (typeof host.OnAppClose === 'function') stops.push(host.OnAppClose(() => setActive(false)));
        const onVisibility = () => setActive(!document.hidden);
        document.addEventListener('visibilitychange', onVisibility);
        return () => {
            stops.forEach(stop => stop?.());
            document.removeEventListener('visibilitychange', onVisibility);
        };
    }, []);

    return active;
}
