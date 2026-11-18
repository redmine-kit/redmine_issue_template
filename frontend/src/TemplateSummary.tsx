import { AttrGrid, Button, Icon, Prose } from '@redmine-kit/ui';
import { useT } from '@redmine-kit/plugin';
import type { SectionData } from './api';

// The template's line at the top of the new issue's form (the part's section, and the settings' preview): its kind, its
// name and 変更 back to the chooser, its description, and the values it sets (as text: the form can't change them). A
// blank issue: its line only.

export function TemplateSummary({ data, onChange }: { data: SectionData; onChange?: () => void }) {
  const t = useT();
  const template = data.template;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      <div className="flex min-h-8 min-w-0 items-center gap-2.5">
        <Icon name={data.blank ? 'plus' : template?.kind === 'form' ? 'grid' : 'document'} size={16} />
        <span className="min-w-0 truncate font-medium">{data.blank ? t('label_issue_template_blank') : template?.name}</span>
        {template && <span className="flex-none text-meta text-text-muted">{template.kind === 'form' ? t('label_issue_template_form') : 'Markdown'}</span>}
        <span className="flex-1" />
        {onChange && (
          <Button size={28} variant="ghost" onClick={onChange}>
            {t('button_change')}
          </Button>
        )}
      </div>
      {template?.about && <Prose text={template.about} />}
      {data.preset && data.preset.length > 0 && <AttrGrid items={data.preset.map((item) => ({ label: item.label, value: item.value }))} />}
    </div>
  );
}
