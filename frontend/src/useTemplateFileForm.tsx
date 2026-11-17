import { useEffect, useState, type ReactNode } from 'react';
import { ApiError, Button, CardSection, FormRow, Input, ListRow, Notice, SectionHeading, Skeleton, SkeletonRegion, Tabs, TabsContent, Textarea, kitApi, useT } from '@redmine-kit/ui';
import { filePath, previewPath, settingsPath, type FileData, type PreviewData } from './api';
import { TemplatePreview } from './TemplatePreview';

// A template file's form, as Redmine's new and edit pages have it: ファイル名 (with the names it takes) and 内容, and
// プレビュー of the text as typed (POST preview.json: the file's messages and what users would see, nothing saved), as
// Redmine's form has its preview button. One form for the drawer the settings tab opens (IssueTemplateFileDrawer) and the
// page of its URL (IssueTemplateEdit): the caller draws the frame, the form gives its body, its errors and its actions.
// 保存 (作成 for a new file) creates or updates the file through the plugin's actions (the same checks as Redmine's form:
// the file's errors come back as Redmine's messages) and is disabled until something changed.

export interface TemplateFileForm {
  title: string;
  /** the save's refusal (Redmine's messages), and the saved file's own messages */
  bands: ReactNode;
  body: ReactNode;
  /** キャンセル and 保存 / 作成, for the frame's FormActions */
  actions: ReactNode;
  dirty: boolean;
}

export function useTemplateFileForm({ project, file, onSaved, onCancel }: { project: { identifier: string }; file?: FileData; onSaved: (created: boolean) => void; onCancel: () => void }): TemplateFileForm {
  const t = useT();
  const [path, setPath] = useState(file?.path ?? '');
  const [content, setContent] = useState(file?.content ?? '');
  const [tab, setTab] = useState('edit');
  const [errors, setErrors] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const dirty = path !== (file?.path ?? '') || content !== (file?.content ?? '');
  const reason = !file || dirty ? undefined : t('kit.common.no_changes');
  const save = () => {
    setSaving(true);
    setErrors([]);
    const body = { issue_template_file: { path, content } };
    const request = file ? kitApi.put(filePath(project, file.id), body) : kitApi.post(settingsPath(project), body);
    request
      .then(() => onSaved(!file))
      .catch((error: unknown) => setErrors(error instanceof ApiError && error.errors.length ? error.errors : [t('kit.error.load_failed')]))
      .finally(() => setSaving(false));
  };
  return {
    title: file ? file.path : t('label_issue_template_file_new'),
    dirty,
    bands: (
      <>
        {errors.length > 0 && <Notice tone="danger" role="alert" wrap text={errors.join('\n')} />}
        {file?.messages.map((message) => <Notice key={message.text} tone={message.level === 'error' ? 'danger' : 'warning'} wrap text={message.text} />)}
      </>
    ),
    body: (
      <Tabs
        aria-label={t('label_issue_template_plural')}
        items={[
          { value: 'edit', label: t('button_edit') },
          { value: 'preview', label: t('label_preview') },
        ]}
        value={tab}
        onValueChange={setTab}
        className="flex min-w-0 flex-col"
      >
        <TabsContent value="edit">
          <div className="flex min-w-0 flex-col gap-4 px-gutter py-section">
            <FormRow layout="stack" label={t('field_filename')} required hint={t('text_issue_template_path_info')}>
              <Input value={path} mono onChange={(event) => setPath(event.target.value)} />
            </FormRow>
            <FormRow layout="stack" label={t('field_content')} required>
              <Textarea rows={16} maxRows={60} mono value={content} onChange={(event) => setContent(event.target.value)} />
            </FormRow>
          </div>
        </TabsContent>
        <TabsContent value="preview">{tab === 'preview' && <FilePreview project={project} id={file?.id} path={path} content={content} />}</TabsContent>
      </Tabs>
    ),
    actions: (
      <>
        <Button data-form-cancel variant="ghost" keycap="Esc" disabled={saving} onClick={onCancel}>
          {t('button_cancel')}
        </Button>
        <Button submit="primary" variant="primary" keycap="⌘↵" disabled={!path.trim() || !!reason || saving} tip={reason} onClick={save}>
          {t(file ? 'button_save' : 'button_create')}
        </Button>
      </>
    ),
  };
}

/** The preview of the text as typed: asked again when the tab opens with another text. */
function FilePreview({ project, id, path, content }: { project: { identifier: string }; id?: number; path: string; content: string }) {
  const t = useT();
  const [answer, setAnswer] = useState<{ key: string; data?: PreviewData; failed?: boolean } | null>(null);
  const key = JSON.stringify([id ?? null, path, content]);
  useEffect(() => {
    let current = true;
    kitApi
      .post<{ preview: PreviewData }>(previewPath(project), { issue_template_file: { id: id ?? '', path, content } })
      .then((data) => current && setAnswer({ key, data: data.preview }))
      .catch(() => current && setAnswer({ key, failed: true }));
    return () => {
      current = false;
    };
  }, [project, id, path, content, key]);
  if (!answer || answer.key !== key) return <PreviewSkeleton />;
  if (answer.failed || !answer.data) return <Notice tone="warning" text={t('kit.error.load_failed')} />;
  return (
    <>
      {answer.data.messages.map((message) => (
        <Notice key={message.text} tone={message.level === 'error' ? 'danger' : 'warning'} wrap text={message.text} />
      ))}
      <TemplatePreview preview={answer.data.preview} />
    </>
  );
}

/** A preview while it comes, laid out as a template's preview (TemplatePreview): the chooser's heading and row, then
 *  新しいチケット with the template's line and the form's first fields. */
export function PreviewSkeleton() {
  const t = useT();
  return (
    <SkeletonRegion label={t('label_loading')} className="flex min-w-0 flex-col pt-section pb-6">
      <SectionHeading heading={t('label_issue_template_chooser')} inset={24} />
      <ListRow
        icon={<Skeleton width={16} height={16} />}
        title={<Skeleton width={140} height={12} className="inline-block align-middle" />}
        sub={<Skeleton width={220} height={10} className="inline-block align-middle" />}
        size={44}
      />
      <CardSection heading={t('label_issue_new')} level={3}>
        <div className="flex min-w-0 flex-col gap-4 px-gutter">
          <div className="flex min-h-8 items-center">
            <Skeleton width={180} height={14} />
          </div>
          <FormRow layout="stack" label={t('field_tracker')} required>
            <Skeleton width="100%" height={32} />
          </FormRow>
          <FormRow layout="stack" label={t('field_subject')} required>
            <Skeleton width="100%" height={32} />
          </FormRow>
        </div>
      </CardSection>
    </SkeletonRegion>
  );
}
