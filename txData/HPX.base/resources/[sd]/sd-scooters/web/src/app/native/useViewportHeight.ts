import { useEffect, useState } from 'react';

export function useViewportHeight(): number {
    const [height, setHeight] = useState(() => (typeof window === 'undefined' ? 956 : window.innerHeight));

    useEffect(() => {
        const onResize = () => setHeight(window.innerHeight);
        onResize();
        window.addEventListener('resize', onResize);
        return () => window.removeEventListener('resize', onResize);
    }, []);

    return height;
}
