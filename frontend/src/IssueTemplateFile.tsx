import { useState } from 'react';
import { Button, Card, CardBody, CardHeader, ConfirmDialog, Notice, RequestErrorState, Skeleton } from '@redmine-kit/ui';
import { kitApi, useApiErrorTexts, useExtensionContext, useKitInvalidate, useKitNavigate, useKitQuery, useT } from '@redmine-kit/plugin';
import { filePath, settingsPath, tabPage, type FileData, type SettingsData } from './api';
import { IssueTemplateFileDrawer } from './IssueTemplateFileDrawer';
import { FileBody, FileBodySkeleton } from './IssueTemplateSettings';

// A template file's own page (/projects/:project_id/issue_templates/:id, the classic issue_templates/show), beside the
// project's settings tabs (チケットテンプレート marked): the address of a file the tab lists (a link, a reload). The header has
// the file's name, ‹ 戻る to the tab, and 編集 and 削除 when the templates are edited here (Redmine's show pages' contextual
// actions); under it what the tab's pane shows of the file (FileBody: its messages, プレビュー, 内容). 編集 opens the file's
// form in a drawer (IssueTemplateFileDrawer), 削除 asks first and goes back to the tab.

type Band = { tone: 'neutral' | 'danger'; text: string };

export function IssueTemplateFile() {
  const t = useT();
  const errorTexts = useApiErrorTexts();
  const { project, params } = useExtensionContext();
  const navigate = useKitNavigate();
  const invalidate = useKitInvalidate();
  const query = useKitQuery<{ issue_template_file: FileData }>(project && params.id ? filePath(project, params.id) : null);
  // whether the templates are edited here (the tab's own answer): 編集 and 削除 only then
  const settings = useKitQuery<{ issue_templates: SettingsData }>(project && settingsPath(project));
  const [drawer, setDrawer] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [band, setBand] = useState<Band | null>(null);
  if (!project) return null;
  const tab = tabPage(project);
  const file = query.data?.issue_template_file;
  const manual = settings.data?.issue_templates.manual;
  // Redmine's refusal in its words, else the app's; nothing after the sudo dialog's キャンセル
  const fail = (error: unknown) => {
    const texts = errorTexts(error);
    setBand(texts.length ? { tone: 'danger', text: texts.join('\n') } : null);
  };
  const remove = (id: number) =>
    kitApi
      .delete(filePath(project, id))
      .then(() => {
        invalidate();
        navigate(tab);
      })
      .catch(fail);

  return (
    <Card aria-label={file?.path ?? t('label_issue_template_plural')}>
      <CardHeader
        back={{ label: t('button_back'), href: tab }}
        title={file ? file.path : query.isPending ? <Skeleton width={160} height={16} className="inline-block align-middle" /> : t('label_issue_template_plural')}
        sidebarToggle
        sidebarLabel={t('label_settings')}
        divider={!band}
        actions={
          file &&
          manual && (
            <>
              <Button icon="edit" onClick={() => (setBand(null), setDrawer(true))}>
                {t('button_edit')}
              </Button>
              <Button variant="danger" icon="delete" onClick={() => setDeleting(true)}>
                {t('button_delete')}
              </Button>
            </>
          )
        }
      />
      {band && <Notice tone={band.tone} role={band.tone === 'danger' ? 'alert' : 'status'} wrap text={band.text} />}
      {file && manual === false && <Notice tone="neutral" wrap text={t('error_issue_template_managed_elsewhere')} />}
      <CardBody className="flex flex-col">
        {query.isError ? (
          <RequestErrorState error={query.error} onRetry={() => void query.refetch()} />
        ) : file ? (
          <FileBody file={file} />
        ) : (
          <FileBodySkeleton />
        )}
      </CardBody>
      {drawer && file && (
        <IssueTemplateFileDrawer
          project={project}
          file={file}
          onClose={() => setDrawer(false)}
          onSaved={() => {
            setDrawer(false);
            setBand({ tone: 'neutral', text: t('notice_successful_update') });
            invalidate();
          }}
        />
      )}
      {deleting && file && (
        <ConfirmDialog
          open
          onOpenChange={(open) => !open && setDeleting(false)}
          title={t('kit.confirm.delete_title', { name: file.path })}
          message={t('kit.confirm.delete_question', { name: file.path })}
          action={t('button_delete')}
          onConfirm={() => {
            setDeleting(false);
            void remove(file.id);
          }}
        />
      )}
    </Card>
  );
}
