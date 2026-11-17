import { useState } from 'react';
import {
  ApiError, AttrGrid, Badge, Button, Checkbox, ConfirmDialog, EmptyState, FormActions, FormRow, Icon, IconButton, Input, ListRow, Notice,
  SectionHeading, Skeleton, SkeletonRegion, Textarea, kitApi, useExtensionContext, useKitQuery, useT,
} from '@redmine-kit/ui';
import { chooserSettingsPath, editPage, filePath, newPage, settingsPath, syncPath, type ContactLink, type FileRow, type SettingsData } from './api';

// Project settings › Issue templates (the manifest's project_settings tab), as Redmine's tab has it (SettingsTab): where
// the templates come from, the files with their state (errors, warnings), and the chooser's settings (config.yml's
// blank_issues_enabled and contact_links). インポート reads the repository again; when the templates are edited here,
// 新しいテンプレート and each file's 編集 open the file's form (the plugin's screens), 削除 asks first, and the chooser's
// settings are saved into config.yml. Templates from elsewhere open read-only (Redmine's file page) and their settings
// can't be changed here.

const DOCS = 'https://redmine-kit.github.io/redmine_issue_template/';

export function IssueTemplateSettings() {
  const t = useT();
  const { project } = useExtensionContext();
  const query = useKitQuery<{ issue_templates: SettingsData }>(project && settingsPath(project));
  const [notice, setNotice] = useState<{ tone: 'neutral' | 'warning' | 'danger'; text: string } | null>(null);
  const [deleting, setDeleting] = useState<FileRow | null>(null);
  if (!project) return null;
  if (query.isPending) return <SettingsSkeleton />;
  if (query.isError) return <Notice tone="warning" text={t('kit.error.load_failed')} />;
  const data = query.data.issue_templates;
  const fail = (error: unknown) => setNotice({ tone: 'danger', text: error instanceof ApiError && error.errors.length ? error.errors.join('\n') : t('kit.error.load_failed') });
  const sync = () =>
    kitApi
      .post<{ kind: 'notice' | 'warning'; message: string }>(syncPath(project), {})
      .then((answer) => {
        setNotice({ tone: answer.kind === 'warning' ? 'warning' : 'neutral', text: answer.message });
        return query.refetch();
      })
      .catch(fail);
  const remove = (file: FileRow) =>
    kitApi
      .delete(filePath(project, file.id))
      .then(() => {
        setNotice({ tone: 'neutral', text: t('notice_successful_delete') });
        return query.refetch();
      })
      .catch(fail);

  return (
    <div className="flex min-w-0 flex-col pb-6">
      {notice && <Notice tone={notice.tone} role="status" wrap text={notice.text} />}
      {data.errors && <Notice tone="danger" wrap text={t('text_issue_template_files_with_errors')} />}
      {data.text_formatting && <Notice tone="warning" wrap text={t('warning_issue_template_text_formatting', { name: data.text_formatting })} />}

      {data.source && (
        <>
          <SectionHeading heading={t('label_repository')} inset={24} className="mt-section" />
          <AttrGrid
            columns={1}
            className="px-gutter"
            items={[
              { label: data.source.kind === 'github' ? 'GitHub' : t('label_repository'), value: data.source.folder },
              ...(data.source.revision ? [{ label: t('label_revision'), value: data.source.revision }] : []),
              ...(data.source.synced_at ? [{ label: t('field_updated_on'), value: new Date(data.source.synced_at).toLocaleString() }] : []),
            ]}
          />
        </>
      )}

      <SectionHeading
        heading={t('label_issue_template_plural')}
        count={data.files.length}
        inset={24}
        className="mt-section"
        actions={
          <>
            <IconButton icon="help" size={28} aria-label={t('label_help')} onClick={() => window.open(DOCS, '_blank', 'noopener,noreferrer')} />
            {data.has_repository && (
              <Button size={28} icon="import" onClick={() => void sync()}>
                {t('button_import')}
              </Button>
            )}
          </>
        }
        action={data.manual ? t('label_issue_template_file_new') : undefined}
        icon="plus"
        href={data.manual ? newPage(project) : undefined}
      />
      {data.files.length === 0 ? (
        <EmptyState variant="block" text={t('label_no_data')} />
      ) : (
        <div className="flex flex-col">
          {data.files.map((file) => (
            <ListRow
              key={file.id}
              id={String(file.id)}
              icon={file.kind === 'config' ? 'settings' : file.kind === 'form' ? 'grid' : 'document'}
              title={file.path}
              mono
              sub={[file.name, file.tracker].filter(Boolean).join(' · ') || undefined}
              href={data.manual ? editPage(project, file.id) : filePath(project, file.id).replace(/\.json$/, '')}
              inset={24}
              divider
              cols={[{ content: <FileState file={file} />, kind: 'muted', width: 96, align: 'right' }]}
              actions={data.manual ? [{ icon: 'delete', label: t('button_delete'), action: 'delete', danger: true }] : []}
              onAction={() => setDeleting(file)}
            />
          ))}
        </div>
      )}

      <ChooserSettings key={JSON.stringify(data.config)} data={data} onSaved={() => setNotice({ tone: 'neutral', text: t('notice_successful_update') })} onError={fail} refetch={() => void query.refetch()} />

      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('kit.confirm.delete_title', { name: deleting?.path ?? '' })}
        onConfirm={() => {
          if (deleting) void remove(deleting);
          setDeleting(null);
        }}
      />
    </div>
  );
}

/** A file's state, as Redmine's tab marks it: its errors (not usable), its warnings, or fine. */
function FileState({ file }: { file: FileRow }) {
  const t = useT();
  if (file.errors) return <Badge tone="danger" icon="warning">{t('label_issue_template_errors', { count: file.errors })}</Badge>;
  if (file.warnings) return <Badge tone="warning" icon="warning">{t('label_issue_template_warnings', { count: file.warnings })}</Badge>;
  return <Icon name="check" size={14} aria-label={t('label_issue_template_usable')} />;
}

/** The chooser's settings (config.yml): saved here when the templates are edited here, read-only otherwise. */
function ChooserSettings({ data, onSaved, onError, refetch }: { data: SettingsData; onSaved: () => void; onError: (error: unknown) => void; refetch: () => void }) {
  const t = useT();
  const { project } = useExtensionContext();
  const [blank, setBlank] = useState(data.config.blank_issues_enabled);
  const [links, setLinks] = useState<ContactLink[]>(data.config.contact_links);
  const [saving, setSaving] = useState(false);
  const filled = links.filter((link) => link.name || link.url || link.about);
  const dirty = blank !== data.config.blank_issues_enabled || JSON.stringify(filled) !== JSON.stringify(data.config.contact_links);
  const readOnly = !data.manual;
  const setLink = (index: number, patch: Partial<ContactLink>) => setLinks((current) => current.map((link, i) => (i === index ? { ...link, ...patch } : link)));
  const save = () => {
    if (!project) return;
    setSaving(true);
    kitApi
      .put(chooserSettingsPath(project), { blank_issues_enabled: blank, contact_links: filled })
      .then(() => {
        onSaved();
        refetch();
      })
      .catch(onError)
      .finally(() => setSaving(false));
  };
  return (
    <>
      <SectionHeading heading={t('label_issue_template_chooser')} inset={24} className="mt-section" />
      <div className="flex flex-col gap-3 px-gutter">
        <Checkbox label={t('label_issue_template_blank_issues_enabled')} checked={blank} readOnly={readOnly} onCheckedChange={(checked) => setBlank(checked === true)} />
      </div>
      <SectionHeading
        heading={t('label_issue_template_contact_links')}
        count={filled.length}
        inset={24}
        className="mt-section"
        action={readOnly ? undefined : t('button_add')}
        icon="plus"
        onAction={() => setLinks((current) => [...current, { name: '', url: '', about: '' }])}
      />
      {links.length === 0 && <EmptyState variant="block" text={t('label_no_data')} />}
      {links.map((link, index) => (
        <div key={index} className="flex min-w-0 flex-col gap-2 px-gutter pb-4">
          <div className="flex min-w-0 items-end gap-2">
            <FormRow layout="stack" label={t('field_name')} className="min-w-0 flex-1">
              <Input value={link.name} readOnly={readOnly} onChange={(event) => setLink(index, { name: event.target.value })} />
            </FormRow>
            <FormRow layout="stack" label={t('field_url')} className="min-w-0 flex-1">
              <Input value={link.url} mono readOnly={readOnly} onChange={(event) => setLink(index, { url: event.target.value })} />
            </FormRow>
            {!readOnly && <IconButton icon="delete" size={32} tone="danger" aria-label={t('button_delete')} onClick={() => setLinks((current) => current.filter((_, i) => i !== index))} />}
          </div>
          <FormRow layout="stack" label={t('field_description')}>
            <Textarea rows={2} value={link.about} readOnly={readOnly} onChange={(event) => setLink(index, { about: event.target.value })} />
          </FormRow>
        </div>
      ))}
      {readOnly ? (
        <p className="px-gutter pt-3 text-meta text-text-muted">{t('text_issue_template_chooser_elsewhere')}</p>
      ) : (
        <FormActions placement="sticky" dirty={dirty}>
          <Button variant="ghost" disabled={!dirty || saving} onClick={() => { setBlank(data.config.blank_issues_enabled); setLinks(data.config.contact_links); }}>
            {t('button_cancel')}
          </Button>
          <Button submit="primary" variant="primary" disabled={!dirty || saving} tip={dirty ? undefined : t('kit.common.no_changes')} onClick={save}>
            {t('button_save')}
          </Button>
        </FormActions>
      )}
    </>
  );
}

function SettingsSkeleton() {
  const t = useT();
  return (
    <SkeletonRegion label={t('label_loading')} className="flex flex-col gap-3 px-gutter py-section">
      <Skeleton width="30%" height={14} />
      <Skeleton width="70%" height={32} />
      <Skeleton width="65%" height={32} />
      <Skeleton width="60%" height={32} />
      <Skeleton width="30%" height={14} />
      <Skeleton width="40%" height={20} />
    </SkeletonRegion>
  );
}
