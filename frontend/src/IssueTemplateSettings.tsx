import { useState } from 'react';
import { AttrGrid, Badge, Button, Checkbox, ConfirmDialog, EmptyState, ExternalLink, FormActions, FormRow, Icon, IconButton, Input, ListRow, Notice, Pane, Panes, RequestErrorState, SectionHeading, Select, Skeleton, SkeletonRegion, Tabs, TabsContent, Textarea } from '@redmine-kit/ui';
import { CardHeaderActions, kitApi, useApiErrorTexts, useExtensionContext, useKitInvalidate, useKitQuery, useT } from '@redmine-kit/plugin';
import { ChooserList } from './ChooserList';
import { IssueTemplateFileDrawer } from './IssueTemplateFileDrawer';
import { TemplatePreview } from './TemplatePreview';
import { PreviewSkeleton } from './useTemplateFileForm';
import { sourceRows } from './source';
import { DOCS, chooserSettingsPath, filePath, settingsPath, sharingPath, syncPath, type ContactLink, type FileData, type FileRow, type Message, type SettingsData } from './api';

// Project settings › Issue templates (the manifest's project_settings tab), as Redmine's tab has it (SettingsTab), in two
// panes: the files at the start (取得元: where they come from, the repository's folder or プロジェクトの設定 for files edited
// here, as the new issue's sidebar says it: sourceRows; each template with its state: errors, warnings, or usable; then
// テンプレートの選択画面, config.yml; 共有, the projects the templates are shared with, as a version's 共有, with 保存 once
// changed, and 共有元, the project whose templates are used while the project has none of its own), the chosen one at the end: its name with 編集 and 削除, its errors and warnings, and
// its tabs: プレビュー (what users see with it, KitPreview, with the new issue form's components), 内容 (the text), and for
// config.yml 設定 (blank_issues_enabled and contact_links, saved into config.yml). Below 1024px the panes stack.
// A file's messages are headed エラー / 警告. 設定 explains 空白のチケットを許可 and notes that saving rewrites config.yml.
// A project without templates of its own lists those it uses from 共有元 read-only (the link mark, their file, tracker and
// project); the empty state only when it has none at all.
// The card's header has ヘルプ, インポート (the project's repository; its tip says it reads the folder now) and
// 新しいテンプレート (CardHeaderActions). A new file and
// 編集 open the file's form in a drawer (IssueTemplateFileDrawer; its URL is the file's page); 削除 asks first. Templates
// from elsewhere are read-only here: no 新しいテンプレート, 編集 or 削除, and the chooser's settings can't be changed.

type Selection = { kind: 'file'; id: number } | { kind: 'config' };
type Band = { tone: 'neutral' | 'warning' | 'danger'; text: string };

export function IssueTemplateSettings() {
  const t = useT();
  const errorTexts = useApiErrorTexts();
  const { project } = useExtensionContext();
  const query = useKitQuery<{ issue_templates: SettingsData }>(project && settingsPath(project));
  const invalidate = useKitInvalidate();
  const [band, setBand] = useState<Band | null>(null);
  const [selected, setSelected] = useState<Selection | null>(null);
  const [deleting, setDeleting] = useState<FileRow | null>(null);
  const [drawer, setDrawer] = useState<{ file?: FileData } | null>(null);
  const [importing, setImporting] = useState(false);
  if (!project) return null;
  if (query.isPending) return <SettingsSkeleton />;
  if (query.isError) return <RequestErrorState error={query.error} onRetry={() => void query.refetch()} />;
  const data = query.data.issue_templates;
  const templates = data.files.filter((file) => file.kind !== 'config');
  const configFile = data.files.find((file) => file.kind === 'config');
  const current: Selection = selected?.kind === 'config' || (selected && templates.some((file) => file.id === selected.id)) ? selected : templates[0] ? { kind: 'file', id: templates[0].id } : { kind: 'config' };
  // Redmine's refusal in its words, else the app's; nothing after the sudo dialog's キャンセル
  const fail = (error: unknown) => {
    const texts = errorTexts(error);
    setBand(texts.length ? { tone: 'danger', text: texts.join('\n') } : null);
  };
  const sync = () =>
    kitApi
      .post<{ kind: 'notice' | 'warning'; message: string }>(syncPath(project), {})
      .then((answer) => {
        setBand({ tone: answer.kind === 'warning' ? 'warning' : 'neutral', text: answer.message });
        invalidate();
      })
      .catch(fail);
  const remove = (file: FileRow) =>
    kitApi
      .delete(filePath(project, file.id))
      .then(() => {
        setBand({ tone: 'neutral', text: t('notice_successful_delete') });
        setSelected(null);
        invalidate();
      })
      .catch(fail);
  const saved = (created: boolean) => {
    setDrawer(null);
    setBand({ tone: 'neutral', text: t(created ? 'notice_successful_create' : 'notice_successful_update') });
    invalidate();
  };

  return (
    <>
      <CardHeaderActions>
        <Button asChild variant="ghost" icon="help">
          <ExternalLink variant="plain" href={DOCS}>
            {t('label_help')}
          </ExternalLink>
        </Button>
        {data.has_repository && (
          // over templates edited here, the import replaces them: it asks first
          <Button icon="import" tip={t('text_issue_template_import_tip')} onClick={() => (data.manual && data.files.length > 0 ? setImporting(true) : void sync())}>
            {t('button_import')}
          </Button>
        )}
        {data.manual && (
          <Button variant="primary" icon="plus" onClick={() => setDrawer({})}>
            {t('label_issue_template_file_new')}
          </Button>
        )}
      </CardHeaderActions>
      {band && <Notice tone={band.tone} role="status" wrap text={band.text} />}
      {data.errors && <Notice tone="danger" wrap text={t('text_issue_template_files_with_errors')} />}
      {data.text_formatting && <Notice tone="warning" wrap text={t('warning_issue_template_text_formatting', { name: data.text_formatting })} />}

      <Panes dividers stacked>
        <Pane as="nav" width={320} sticky aria-label={t('label_issue_template_plural')} className="pb-6">
          {/* where the templates come from: the repository's folder, or the project's settings (edited here) */}
          <SectionHeading heading={t('label_issue_template_source')} inset={24} className="mt-section" />
          <AttrGrid columns={1} className="px-gutter" items={sourceRows(data.source, t).map(({ label, value, href }) => ({ label, value, href }))} />
          <SharingField key={data.sharing} data={data} onSaved={() => { setBand({ tone: 'neutral', text: t('notice_successful_update') }); invalidate(); }} onError={fail} />
          <SectionHeading heading={t('label_issue_template_plural')} count={templates.length + data.shared_files.length} inset={24} className="mt-section" />
          {templates.length === 0 && data.shared_files.length === 0 && <EmptyState variant="block" text={t('label_no_data')} />}
          {/* the provider's templates the project uses, read-only: the link mark and their project, as a shared route or
              version is marked */}
          {data.provider &&
            data.shared_files.map((file) => (
              <ListRow
                key={`shared-${file.path}`}
                id={`shared-${file.path}`}
                icon="link"
                title={file.name ?? file.path}
                sub={[file.path, file.tracker, data.provider?.name].filter(Boolean).join(' · ')}
              />
            ))}
          {templates.map((file) => (
            <ListRow
              key={file.id}
              id={String(file.id)}
              icon={file.kind === 'form' ? 'grid' : 'document'}
              title={file.name ?? file.path}
              sub={[file.path, file.tracker].filter(Boolean).join(' · ')}
              selected={current.kind === 'file' && current.id === file.id}
              onSelect={() => setSelected({ kind: 'file', id: file.id })}
              cols={[{ content: <FileState file={file} />, kind: 'muted', width: 104, align: 'right' }]}
            />
          ))}
          <ListRow
            id="config"
            icon="settings"
            title={t('label_issue_template_chooser')}
            sub={data.config.path}
            selected={current.kind === 'config'}
            onSelect={() => setSelected({ kind: 'config' })}
            cols={configFile ? [{ content: <FileState file={configFile} />, kind: 'muted', width: 104, align: 'right' }] : undefined}
          />
        </Pane>
        <Pane as="section" className="flex flex-col">
          {current.kind === 'config' ? (
            <ConfigPane key="config" data={data} file={configFile} onEdit={(file) => setDrawer({ file })} onSaved={() => { setBand({ tone: 'neutral', text: t('notice_successful_update') }); invalidate(); }} onError={fail} />
          ) : (
            <FilePane key={current.id} id={current.id} manual={data.manual} onEdit={(file) => setDrawer({ file })} onDelete={setDeleting} files={data.files} />
          )}
        </Pane>
      </Panes>

      {drawer && <IssueTemplateFileDrawer project={project} file={drawer.file} onClose={() => setDrawer(null)} onSaved={saved} />}
      <ConfirmDialog
        open={importing}
        onOpenChange={setImporting}
        title={t('button_import')}
        description={t('text_issue_template_import_replace')}
        action={t('button_import')}
        onConfirm={() => {
          setImporting(false);
          void sync();
        }}
      />
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('kit.confirm.delete_title', { name: deleting?.path ?? '' })}
        description={t('text_are_you_sure')}
        action={t('button_delete')}
        onConfirm={() => {
          if (deleting) void remove(deleting);
          setDeleting(null);
        }}
      />
    </>
  );
}

/** 共有 (Redmine's version sharings, the values the user may set) with 保存 once changed, and 共有元 when another project's
 *  templates are used. */
function SharingField({ data, onSaved, onError }: { data: SettingsData; onSaved: () => void; onError: (error: unknown) => void }) {
  const t = useT();
  const { project } = useExtensionContext();
  const [sharing, setSharing] = useState(data.sharing);
  const [saving, setSaving] = useState(false);
  const save = () => {
    if (!project) return;
    setSaving(true);
    kitApi
      .put(sharingPath(project), { sharing })
      .then(onSaved)
      .catch(onError)
      .finally(() => setSaving(false));
  };
  return (
    <>
      <SectionHeading heading={t('field_sharing')} inset={24} className="mt-section" />
      <div className="flex min-w-0 items-center gap-2 px-gutter">
        <Select aria-label={t('field_sharing')} value={sharing} options={data.sharings.map((value) => ({ value, label: t(`label_version_sharing_${value}`) }))} onValueChange={setSharing} className="min-w-0 flex-1" />
        <Button disabled={sharing === data.sharing || saving} onClick={save}>
          {t('button_save')}
        </Button>
      </div>
      {data.provider && <AttrGrid columns={1} className="mt-3 px-gutter" items={[{ label: t('label_issue_template_provider'), value: data.provider.name, href: `/projects/${encodeURIComponent(data.provider.identifier)}` }]} />}
    </>
  );
}

/** A file's error or warning, with its heading (エラー / 警告) and Redmine's sentence. */
function MessageNotice({ message }: { message: Message }) {
  const t = useT();
  const error = message.level === 'error';
  return <Notice tone={error ? 'danger' : 'warning'} heading={error ? t('label_issue_template_error') : t('label_alert_warning')} wrap text={message.text} />;
}

/** A file's state, as Redmine's tab marks it: its errors (not usable), its warnings, or usable. */
function FileState({ file }: { file: FileRow }) {
  const t = useT();
  if (file.errors) return <Badge tone="danger" icon="warning">{t('label_issue_template_errors', { count: file.errors })}</Badge>;
  if (file.warnings) return <Badge tone="warning" icon="warning">{t('label_issue_template_warnings', { count: file.warnings })}</Badge>;
  return <Icon name="check" size={14} aria-label={t('label_issue_template_usable')} />;
}

/** The pane's heading: the file's name, and 編集 and 削除 when the templates are edited here. */
function FileHeading({ path, onEdit, onDelete, elsewhere }: { path: string; onEdit?: () => void; onDelete?: () => void; elsewhere: boolean }) {
  const t = useT();
  // from elsewhere: the line under the name says where they are edited (beside it, it would squeeze the name at a phone's width)
  if (elsewhere)
    return (
      <>
        <SectionHeading heading={path} inset={24} className="mt-section" />
        <p className="-mt-1 px-gutter pb-3 text-meta text-text-muted">{t('error_issue_template_managed_elsewhere')}</p>
      </>
    );
  return (
    <SectionHeading
      heading={path}
      inset={24}
      className="mt-section"
      actions={
        <>
          {onEdit && (
            <Button size={28} icon="edit" onClick={onEdit}>
              {t('button_edit')}
            </Button>
          )}
          {onDelete && (
            <Button size={28} variant="danger" icon="delete" onClick={onDelete}>
              {t('button_delete')}
            </Button>
          )}
        </>
      }
    />
  );
}

/** A template file: its messages, プレビュー and 内容 (GET the file: its text, messages and preview). */
function FilePane({ id, manual, files, onEdit, onDelete }: { id: number; manual: boolean; files: FileRow[]; onEdit: (file: FileData) => void; onDelete: (file: FileRow) => void }) {
  const t = useT();
  const { project } = useExtensionContext();
  const query = useKitQuery<{ issue_template_file: FileData }>(project && filePath(project, id));
  const row = files.find((file) => file.id === id);
  if (query.isPending) return <FilePaneSkeleton path={row?.path} />;
  if (query.isError) return <RequestErrorState error={query.error} onRetry={() => void query.refetch()} />;
  const file = query.data.issue_template_file;
  return (
    <>
      <FileHeading path={file.path} elsewhere={!manual} onEdit={() => onEdit(file)} onDelete={row ? () => onDelete(row) : undefined} />
      <FileBody file={file} />
    </>
  );
}

/** What a template file shows under its name, in the tab's pane and on the file's page (IssueTemplateFile): its messages,
 *  then プレビュー and 内容. */
export function FileBody({ file }: { file: FileData }) {
  const t = useT();
  const [tab, setTab] = useState('preview');
  return (
    <>
      {file.messages.map((message) => (
        <MessageNotice key={message.text} message={message} />
      ))}
      <Tabs aria-label={file.path} items={[{ value: 'preview', label: t('label_preview') }, { value: 'content', label: t('field_content') }]} value={tab} onValueChange={setTab} className="flex min-w-0 flex-col">
        <TabsContent value="preview">
          <TemplatePreview preview={file.preview} />
        </TabsContent>
        <TabsContent value="content">
          <FileContent content={file.content} />
        </TabsContent>
      </Tabs>
    </>
  );
}

/** FileBody while the file comes: its tabs and the preview's skeleton. */
export function FileBodySkeleton({ path }: { path?: string }) {
  const t = useT();
  return (
    <Tabs aria-label={path ?? t('label_loading')} items={[{ value: 'preview', label: t('label_preview') }, { value: 'content', label: t('field_content') }]} value="preview" className="flex min-w-0 flex-col">
      <PreviewSkeleton />
    </Tabs>
  );
}

function FileContent({ content }: { content: string }) {
  const t = useT();
  return (
    <div className="px-gutter py-section">
      <Textarea readOnly mono aria-label={t('field_content')} rows={Math.min(content.split('\n').length, 80)} maxRows={80} value={content} />
    </div>
  );
}

/** config.yml: 設定 (the chooser's settings), プレビュー (the chooser the templates make) and 内容 (when the file exists). */
function ConfigPane({ data, file, onEdit, onSaved, onError }: { data: SettingsData; file?: FileRow; onEdit: (file: FileData) => void; onSaved: () => void; onError: (error: unknown) => void }) {
  const t = useT();
  const { project } = useExtensionContext();
  const query = useKitQuery<{ issue_template_file: FileData }>(project && file ? filePath(project, file.id) : null);
  const [tab, setTab] = useState('settings');
  const loaded = file ? query.data?.issue_template_file : undefined;
  return (
    <>
      <FileHeading path={data.config.path} elsewhere={!data.manual} onEdit={loaded ? () => onEdit(loaded) : undefined} />
      {loaded?.messages.map((message) => (
        <MessageNotice key={message.text} message={message} />
      ))}
      <Tabs
        aria-label={data.config.path}
        items={[{ value: 'settings', label: t('label_settings') }, { value: 'preview', label: t('label_preview') }, ...(file ? [{ value: 'content', label: t('field_content') }] : [])]}
        value={tab}
        onValueChange={setTab}
        className="flex min-w-0 flex-col"
      >
        <TabsContent value="settings">
          <ChooserSettings key={JSON.stringify(data.config)} data={data} onSaved={onSaved} onError={onError} />
        </TabsContent>
        <TabsContent value="preview">
          <div inert className="flex min-w-0 flex-col pt-section pb-6">
            <ChooserList data={data.chooser} />
          </div>
        </TabsContent>
        {file && <TabsContent value="content">{loaded ? <FileContent content={loaded.content} /> : <PreviewSkeleton />}</TabsContent>}
      </Tabs>
    </>
  );
}

/** The chooser's settings (config.yml): saved here when the templates are edited here, read-only otherwise. */
function ChooserSettings({ data, onSaved, onError }: { data: SettingsData; onSaved: () => void; onError: (error: unknown) => void }) {
  const t = useT();
  const { project } = useExtensionContext();
  const [blank, setBlank] = useState(data.config.blank_issues_enabled);
  const [links, setLinks] = useState<ContactLink[]>(data.config.contact_links);
  const [saving, setSaving] = useState(false);
  const filled = links.filter((link) => link.name || link.url || link.about);
  const dirty = blank !== data.config.blank_issues_enabled || JSON.stringify(filled) !== JSON.stringify(data.config.contact_links);
  const readOnly = !data.manual;
  const setLink = (index: number, patch: Partial<ContactLink>) => setLinks((list) => list.map((link, i) => (i === index ? { ...link, ...patch } : link)));
  const save = () => {
    if (!project) return;
    setSaving(true);
    kitApi
      .put(chooserSettingsPath(project), { blank_issues_enabled: blank, contact_links: filled })
      .then(onSaved)
      .catch(onError)
      .finally(() => setSaving(false));
  };
  return (
    <div className="flex min-w-0 flex-col">
      <div className="flex flex-col gap-3 px-gutter pt-section">
        <Checkbox
          label={t('label_issue_template_blank_issues_enabled')}
          description={t('text_issue_template_blank_issues_info')}
          checked={blank}
          disabled={readOnly}
          onCheckedChange={(checked) => setBlank(checked === true)}
        />
      </div>
      <SectionHeading
        heading={t('label_issue_template_contact_links')}
        count={filled.length}
        inset={24}
        className="mt-section"
        action={readOnly ? undefined : t('button_add')}
        icon="plus"
        onAction={() => setLinks((list) => [...list, { name: '', url: '', about: '' }])}
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
            {!readOnly && <IconButton icon="delete" size={32} tone="danger" aria-label={t('button_delete')} onClick={() => setLinks((list) => list.filter((_, i) => i !== index))} />}
          </div>
          <FormRow layout="stack" label={t('field_description')}>
            <Textarea rows={2} value={link.about} readOnly={readOnly} onChange={(event) => setLink(index, { about: event.target.value })} />
          </FormRow>
        </div>
      ))}
      {readOnly ? (
        <p className="px-gutter pt-3 pb-6 text-meta text-text-muted">{t('text_issue_template_chooser_elsewhere')}</p>
      ) : (
        <FormActions placement="sticky" edge dirty={dirty} note={t('text_issue_template_config_rewrite')}>
          <Button
            variant="ghost"
            disabled={!dirty || saving}
            onClick={() => {
              setBlank(data.config.blank_issues_enabled);
              setLinks(data.config.contact_links);
            }}
          >
            {t('button_cancel')}
          </Button>
          <Button submit="primary" variant="primary" disabled={!dirty || saving} tip={dirty ? undefined : t('kit.common.no_changes')} onClick={save}>
            {t('button_save')}
          </Button>
        </FormActions>
      )}
    </div>
  );
}

/** A file's pane while its text and preview come: its heading (the name, known from the list), its tabs, the preview. */
function FilePaneSkeleton({ path }: { path?: string }) {
  const t = useT();
  return (
    <>
      <SectionHeading heading={path ?? <Skeleton width={160} height={14} className="inline-block align-middle" />} inset={24} className="mt-section" />
      <FileBodySkeleton path={path} />
    </>
  );
}

/** A row of the files' list while it comes: the ListRow itself, with bars for its icon, name and file name. */
function RowSkeleton({ id, width }: { id: string; width: number }) {
  // the bars inline, in the row's text lines, so that the row is as tall as a loaded one
  return (
    <ListRow
      id={id}
      icon={<Skeleton width={16} height={16} />}
      title={<Skeleton width={width} height={12} className="inline-block align-middle" />}
      sub={<Skeleton width={width * 0.7} height={10} className="inline-block align-middle" />}
    />
  );
}

/** The tab while its files come: the two panes as the loaded tab lays them out (the list's heading and rows, the chosen
 *  file's heading, tabs and preview), so that nothing moves when the files arrive. */
function SettingsSkeleton() {
  const t = useT();
  return (
    <SkeletonRegion label={t('label_loading')} className="flex min-h-0 min-w-0 flex-1 flex-col">
      {/* the header's actions as bars: at a phone's width they take the header's second line */}
      <CardHeaderActions>
        <Skeleton width={88} height={32} />
        <Skeleton width={160} height={32} />
      </CardHeaderActions>
      <Panes dividers stacked>
        <Pane as="nav" width={320} sticky aria-label={t('label_issue_template_plural')} className="pb-6">
          {/* 取得元 with its first row (the source's other rows follow it when it is a repository) */}
          <SectionHeading heading={t('label_issue_template_source')} inset={24} className="mt-section" />
          <AttrGrid columns={1} className="px-gutter" items={[{ label: t('label_issue_template_source'), value: <Skeleton width={120} height={12} className="inline-block align-middle" /> }]} />
          {/* 共有 with its select and 保存 (共有元, rare, comes with the data) */}
          <SectionHeading heading={t('field_sharing')} inset={24} className="mt-section" />
          <div className="flex min-w-0 items-center gap-2 px-gutter">
            <Skeleton height={32} className="min-w-0 flex-1" />
            <Skeleton width={64} height={32} />
          </div>
          <SectionHeading heading={t('label_issue_template_plural')} inset={24} className="mt-section" />
          <RowSkeleton id="1" width={120} />
          <RowSkeleton id="2" width={96} />
          <RowSkeleton id="3" width={140} />
        </Pane>
        <Pane as="section" className="flex flex-col">
          <FilePaneSkeleton />
        </Pane>
      </Panes>
    </SkeletonRegion>
  );
}
