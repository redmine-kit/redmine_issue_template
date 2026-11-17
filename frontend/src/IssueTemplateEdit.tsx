import { useState } from 'react';
import {
  ApiError, Button, Card, CardBody, CardHeader, ErrorState, FormActions, FormActionsSkeleton, FormRow, Input, Notice, Skeleton, SkeletonRegion,
  Textarea, kitApi, useExtensionContext, useKitNavigate, useKitQuery, useT,
} from '@redmine-kit/ui';
import { filePath, settingsPath, tabPage, type FileData } from './api';

// A template file's form (the manifest's screens: /projects/:project_id/issue_templates/new and …/:id/edit), as Redmine's
// new and edit pages have it: ファイル名 (with the names it takes) and 内容. 保存 creates or updates the file through the
// plugin's actions (the same checks as Redmine's form: the file's errors come back as Redmine's messages), then goes back
// to the settings tab; キャンセル goes back without saving.

export function IssueTemplateEdit() {
  const t = useT();
  const { project, params } = useExtensionContext();
  const id = params.id;
  const query = useKitQuery<{ issue_template_file: FileData }>(project && id ? filePath(project, id) : null);
  if (!project) return null;
  if (id && query.isPending) return <EditSkeleton />;
  if (id && query.isError) {
    const status = query.error instanceof ApiError ? query.error.status : 0;
    return (
      <Card aria-label={t('label_issue_template_plural')}>
        <CardBody className="flex flex-col px-gutter">
          {status === 403 || status === 404 ? (
            <ErrorState status={status} title={t(status === 403 ? 'notice_not_authorized' : 'notice_file_not_found')} />
          ) : (
            <ErrorState icon="warning" title={t('kit.error.load_failed')} actions={<Button onClick={() => void query.refetch()}>{t('kit.error.reload')}</Button>} />
          )}
        </CardBody>
      </Card>
    );
  }
  return <FileForm key={id ?? 'new'} project={project} file={id ? query.data?.issue_template_file : undefined} />;
}

function FileForm({ project, file }: { project: { identifier: string; name: string }; file?: FileData }) {
  const t = useT();
  const navigate = useKitNavigate();
  const [path, setPath] = useState(file?.path ?? '');
  const [content, setContent] = useState(file?.content ?? '');
  const [errors, setErrors] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const dirty = path !== (file?.path ?? '') || content !== (file?.content ?? '');
  const back = () => navigate(tabPage(project));
  const save = () => {
    setSaving(true);
    setErrors([]);
    const body = { issue_template_file: { path, content } };
    const request = file ? kitApi.put(filePath(project, file.id), body) : kitApi.post(settingsPath(project), body);
    request
      .then(back)
      .catch((error: unknown) => setErrors(error instanceof ApiError && error.errors.length ? error.errors : [t('kit.error.load_failed')]))
      .finally(() => setSaving(false));
  };
  const title = file ? file.path : t('label_issue_template_file_new');
  return (
    <Card aria-label={title}>
      <CardHeader title={title} subtitle={project.name} divider={errors.length === 0 && !file?.messages.length} />
      {errors.length > 0 && <Notice tone="danger" role="alert" wrap text={errors.join('\n')} />}
      {file?.messages.map((message) => (
        <Notice key={message.text} tone={message.level === 'error' ? 'danger' : 'warning'} wrap text={message.text} />
      ))}
      <CardBody className="flex flex-col gap-4 px-gutter py-section">
        <FormRow layout="stack" label={t('field_filename')} required hint={t('text_issue_template_path_info')}>
          <Input value={path} mono onChange={(event) => setPath(event.target.value)} />
        </FormRow>
        <FormRow layout="stack" label={t('field_content')}>
          <Textarea rows={16} maxRows={60} mono value={content} onChange={(event) => setContent(event.target.value)} />
        </FormRow>
      </CardBody>
      <FormActions placement="sticky" dirty={dirty}>
        <Button data-form-cancel variant="ghost" disabled={saving} onClick={back}>
          {t('button_cancel')}
        </Button>
        <Button submit="primary" variant="primary" keycap="⌘↵" disabled={!path.trim() || saving} onClick={save}>
          {t('button_save')}
        </Button>
      </FormActions>
    </Card>
  );
}

function EditSkeleton() {
  const t = useT();
  return (
    <Card aria-label={t('label_loading')}>
      <CardHeader title={<Skeleton width={200} height={16} />} divider />
      <SkeletonRegion label={t('label_loading')} className="flex flex-col gap-4 px-gutter py-section">
        <Skeleton width="40%" height={32} />
        <Skeleton width="100%" height={320} />
      </SkeletonRegion>
      <FormActionsSkeleton />
    </Card>
  );
}
