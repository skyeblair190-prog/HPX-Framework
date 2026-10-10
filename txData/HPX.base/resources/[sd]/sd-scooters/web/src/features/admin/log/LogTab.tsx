import { useEffect, useState } from 'react';
import { query } from '@/nui/api';
import { useQuery, useSlow } from '@/nui/useQuery';
import { t } from '@/i18n';
import { ago, Empty, Heading, SearchInput, Skeleton } from '@/components/shared';
import type { AuditRow, Page } from '@/types';

export const LogTab = () => {
  const [search, setSearch] = useState('');
  const [term, setTerm] = useState('');
  const [more, setMore] = useState<AuditRow[]>([]);
  const { data: first } = useQuery<Page<AuditRow>>('auditlog', { query: term, offset: 0 }, { refreshMs: 15000 });
  const slow = useSlow(!first);

  useEffect(() => {
    const id = window.setTimeout(() => setTerm(search.trim()), search ? 250 : 0);
    return () => window.clearTimeout(id);
  }, [search]);
  useEffect(() => setMore([]), [term]);

  const page: Page<AuditRow> | null = first ? { ...first, rows: [...first.rows, ...more] } : null;
  const loadMore = async () => {
    if (!page) return;
    const next = await query<Page<AuditRow>>('auditlog', { query: term, offset: page.rows.length });
    if (next) setMore(prev => [...prev, ...next.rows]);
  };

  return (
    <div className="flex flex-col h-full min-h-0 px-6 py-5 gap-4">
      <Heading title={t('log.title')} count={page?.total}>
        <div className="w-72 flex">
          <SearchInput value={search} onChange={setSearch} placeholder={t('log.search')} />
        </div>
      </Heading>
      <div className="flex-1 min-h-0 overflow-y-auto sc-scroll">
        {!page ? (
          slow && <Skeleton rows={8} height={48} />
        ) : page.rows.length === 0 ? (
          <Empty text={t('log.empty')} />
        ) : (
          <div className="flex flex-col gap-3">
            <div className="sc-list">
              {page.rows.map(row => (
                <div key={row.id} className="sc-row" style={{ minHeight: 48 }}>
                  <span className="text-[12.5px] font-medium w-36 truncate">{row.actor}</span>
                  <span className="text-[12.5px] flex-1 min-w-0 truncate" style={{ color: 'var(--text-2)' }} title={row.message}>
                    {row.message}
                  </span>
                  <span className="text-[11.5px] w-28 text-right pr-2" style={{ color: 'var(--text-3)' }} title={new Date(row.at * 1000).toLocaleString()}>
                    {ago(row.at)}
                  </span>
                </div>
              ))}
            </div>
            {page.rows.length < page.total && (
              <button type="button" className="sc-btn self-center" onClick={() => void loadMore()}>
                {t('common.load_more')}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
