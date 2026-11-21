import { Button, Card, CardBody, CardHeader, ExternalLink, FormActions, FormActionsSkeleton, FormRow, Pane, Panes, Prose, RequestErrorState, SectionHeading, Skeleton, SkeletonRegion, Tabs } from '@redmine-kit/ui';
import { useExtensionContext, useKitNavigate, useKitQuery, useT } from '@redmine-kit/plugin';
import { DOCS, filePath, tabPage, type FileData } from './api';
import { useTemplateFileForm } from './useTemplateFileForm';

// A template file's page (the manifest's screens: /projects/:project_id/issue_templates/new and …/:id/edit, with the
// project's settings tabs beside it, チケットテンプレート marked): the URL opened directly (a reload, a link); inside the
// app the settings tab opens the same form in a drawer (IssueTemplateFileDrawer). ‹ 戻る and キャンセル go back to the tab,
// 保存 goes back after saving. Beside the form, 形式のヘルプ: the format in short and ヘルプ, the full documentation.

export function IssueTemplateEdit() {
  const t = useT();
  const { project, params } = useExtensionContext();
  const id = params.id;
  const query = useKitQuery<{ issue_template_file: FileData }>(project && id ? filePath(project, id) : null);
  if (!project) return null;
  if (id && query.isPending) return <EditSkeleton />;
  if (id && query.isError) {
    return (
      <Card aria-label={t('label_issue_template_plural')}>
        <CardBody className="flex flex-col px-gutter">
          <RequestErrorState error={query.error} onRetry={() => void query.refetch()} />
        </CardBody>
      </Card>
    );
  }
  return <FilePage key={id ?? 'new'} project={project} file={id ? query.data?.issue_template_file : undefined} />;
}

function FilePage({ project, file }: { project: { identifier: string }; file?: FileData }) {
  const t = useT();
  const navigate = useKitNavigate();
  const back = () => navigate(tabPage(project));
  const form = useTemplateFileForm({ project, file, onSaved: back, onCancel: back });
  return (
    <Card aria-label={form.title}>
      <CardHeader
        back={{ label: t('button_back'), href: tabPage(project) }}
        title={form.title}
        sidebarToggle
        sidebarLabel={t('label_settings')}
        divider
      />
      {form.bands}
      {/* one scroll (ui docs/components/forms.md "One scroll per form"): the format's help a sticky side column, the form's
          actions the scroller's sticky last row */}
      <Panes
        dividers
        stacked
        footer={
          <FormActions placement="sticky" edge dirty={form.dirty}>
            {form.actions}
          </FormActions>
        }
      >
        <Pane as="section" aria-label={form.title} className="flex flex-col">
          {form.body}
        </Pane>
        <Pane as="aside" width={360} sticky aria-label={t('label_issue_template_format_help')} className="pb-6">
          <FormatHelp />
        </Pane>
      </Panes>
      {form.dialog}
    </Card>
  );
}

/** The format in short, and the full documentation. */
function FormatHelp() {
  const t = useT();
  return (
    <>
      <SectionHeading heading={t('label_issue_template_format_help')} inset={24} className="mt-section" />
      <div className="flex flex-col gap-3 px-gutter">
        <Prose text={t('text_issue_template_format_help')} />
        <Button asChild variant="plain" size={28} iconEnd="external" className="self-start">
          <ExternalLink variant="plain" href={DOCS}>
            {t('label_help')}
          </ExternalLink>
        </Button>
      </div>
    </>
  );
}

/** The page while the file comes: the loaded page's header, panes, tabs, fields and help, with bars for the file's name and
 *  text, so that nothing moves when it arrives (the text's height is the file's). */
function EditSkeleton() {
  const t = useT();
  const { project } = useExtensionContext();
  return (
    <Card aria-label={t('label_loading')}>
      <CardHeader
        back={project ? { label: t('button_back'), href: tabPage(project) } : undefined}
        title={<Skeleton width={120} height={16} className="inline-block align-middle" />}
        sidebarToggle
        sidebarLabel={t('label_settings')}
        divider
      />
      <Panes dividers stacked footer={<FormActionsSkeleton edge />}>
        <Pane as="section" className="flex flex-col">
          <Tabs aria-label={t('label_loading')} items={[{ value: 'edit', label: t('button_edit') }, { value: 'preview', label: t('label_preview') }]} value="edit" className="flex min-w-0 flex-col">
            <SkeletonRegion label={t('label_loading')} className="flex min-w-0 flex-col gap-4 px-gutter py-section">
              <FormRow layout="stack" label={t('field_filename')} required hint={t('text_issue_template_path_info')}>
                <Skeleton width="100%" height={32} />
              </FormRow>
              <FormRow layout="stack" label={t('field_content')} required>
                <Skeleton width="100%" height={320} />
              </FormRow>
            </SkeletonRegion>
          </Tabs>
        </Pane>
        <Pane as="aside" width={360} sticky aria-label={t('label_issue_template_format_help')} className="pb-6">
          <FormatHelp />
        </Pane>
      </Panes>
    </Card>
  );
}
