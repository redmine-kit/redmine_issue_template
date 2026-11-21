import { Button, ErrorState } from '@redmine-kit/ui';
import { ApiError, useT } from '@redmine-kit/plugin';

/** A read that failed, on the plugin's pages, its settings tab and the tab's file pane: Redmine's 403 and 404, else
 *  読み込めませんでした with 再読み込み (never the error's own text). */
export function LoadError({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  const t = useT();
  const status = error instanceof ApiError ? error.status : 0;
  if (status === 403 || status === 404) return <ErrorState status={status} title={t(status === 403 ? 'notice_not_authorized' : 'notice_file_not_found')} />;
  return <ErrorState icon="warning" title={t('kit.error.load_failed')} actions={<Button onClick={onRetry}>{t('kit.error.reload')}</Button>} />;
}
