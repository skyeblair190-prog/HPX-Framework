import { Clock, MapPin, Zap } from 'lucide-react';

import { t } from '../compat/i18n';
import { useSessionState } from '../compat/hooks/useSessionState';
import { TabBar, type TabBarItem } from '../compat/ui/TabBar';
import { Home } from './Home';
import { Rides } from './Rides';
import { Stations } from './Stations';

type Tab = 'ride' | 'stations' | 'rides';

export function Scoot() {
    const [tab, setTab] = useSessionState<Tab>('scoot:tab', 'ride');
    const PUSH = 'ios-push 0.34s cubic-bezier(0.32,0.72,0,1)';
    return (
        <div data-phone-screen className="absolute inset-0 flex flex-col bg-base font-sf">
            <div className="relative min-h-0 flex-1">
                <div key={tab} className="absolute inset-0" style={{ animation: PUSH }}>
                    {tab === 'ride' && <Home />}
                    {tab === 'stations' && <Stations onPicked={() => setTab('ride')} />}
                    {tab === 'rides' && <Rides onOpenRide={() => setTab('ride')} />}
                </div>
            </div>
            <TabBar tabs={scootTabs()} active={tab} onChange={setTab} activeClassName="text-[#14b8a6]" />
        </div>
    );
}

const scootTabs = (): TabBarItem<Tab>[] => [
    { id: 'ride',     label: t('scoot.tabRide', 'Ride'),         icon: a => <MapPin className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} /> },
    { id: 'stations', label: t('scoot.tabStations', 'Stations'), icon: a => <Zap    className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} /> },
    { id: 'rides',    label: t('scoot.tabRides', 'Rides'),       icon: a => <Clock  className="h-[33px] w-[33px]" strokeWidth={a ? 2.2 : 1.9} /> },
];
