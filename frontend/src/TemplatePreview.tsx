import { CardSection, EmptyState, FormRow, Input, ListRow, SectionHeading, Textarea } from '@redmine-kit/ui';
import { useT } from '@redmine-kit/plugin';
import type { Preview } from './api';
import { ChooserList } from './ChooserList';
import { TemplateQuestions } from './TemplateQuestions';
import { TemplateSummary } from './TemplateSummary';
import { startingAnswers } from './answers';

// What users see with a file (the settings' プレビュー and the file form's), shown but not usable (inert), as the server
// gives it (KitPreview), drawn with the same components as the new issue's form: config.yml's chooser (ChooserList); a
// template's row of the chooser, then 新しいチケット with the template: its line and the values it sets (TemplateSummary),
// the tracker and the subject the form starts with, and a YAML form's fields (TemplateQuestions) or a Markdown template's
// description. The form's other fields are Redmine's own, as the template leaves them. A file with errors has no preview:
// it is left out of the chooser.

export function TemplatePreview({ preview }: { preview: Preview | null }) {
  const t = useT();
  if (!preview) return <EmptyState variant="block" text={t('text_issue_template_unusable')} />;
  if (preview.kind === 'config')
    return (
      <div inert className="flex min-w-0 flex-col pt-section pb-6">
        <ChooserList data={preview.chooser} />
      </div>
    );
  const row = preview.chooser_row;
  return (
    <div className="flex min-w-0 flex-col pt-section pb-6">
      <SectionHeading heading={t('label_issue_template_chooser')} inset={24} />
      <div inert>
        <ListRow icon={row.kind === 'form' ? 'grid' : 'document'} title={row.name} sub={row.about || undefined} size={44} cols={[{ content: row.tracker ?? '', kind: 'text', width: 88 }]} />
      </div>
      <CardSection heading={t('label_issue_new')} level={3}>
        <div inert className="flex min-w-0 flex-col gap-4 px-gutter">
          <TemplateSummary data={preview.section} />
          <FormRow layout="stack" label={t('field_tracker')} required>
            <Input readOnly value={preview.issue.tracker ?? ''} />
          </FormRow>
          <FormRow layout="stack" label={t('field_subject')} required>
            <Input readOnly value={preview.issue.subject} />
          </FormRow>
          <TemplateQuestions elements={preview.section.elements ?? []} answers={startingAnswers(preview.section.elements ?? [])} />
          {preview.issue.description != null && (
            <FormRow layout="stack" label={t('field_description')}>
              <Textarea readOnly rows={6} maxRows={20} value={preview.issue.description} />
            </FormRow>
          )}
        </div>
      </CardSection>
    </div>
  );
}

