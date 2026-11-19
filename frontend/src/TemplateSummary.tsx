import { AttrGrid, Icon, IconButton, Prose } from '@redmine-kit/ui';
import { useT } from '@redmine-kit/plugin';
import type { SectionData } from './api';

// The template's line at the top of the new issue's form (the part's section, and the settings' preview): ‹ back to the
// chooser before its name (an arrow, not a 変更 label: the user, 2026-11-12), its kind and its name, then its description.
// The preview (no `onBack`) lists the values it sets as text (`preset`); the form shows them at their fields, read-only.
// A blank issue: its line only.

export function TemplateSummary({ data, onBack }: { data: SectionData; onBack?: () => void }) {
  const t = useT();
  const template = data.template;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      <div className="flex min-h-8 min-w-0 items-center gap-2.5">
        {onBack && <IconButton icon="chevron-left" size={28} aria-label={t('label_issue_template_back_to_chooser')} onClick={onBack} className="-ms-1.5 flex-none" />}
        <Icon name={data.blank ? 'plus' : template?.kind === 'form' ? 'grid' : 'document'} size={16} className="flex-none text-text-muted" />
        <span className="min-w-0 truncate font-medium" title={data.blank ? undefined : template?.name}>
          {data.blank ? t('label_issue_template_blank') : template?.name}
        </span>
        {template && <span className="flex-none text-meta text-text-muted">{template.kind === 'form' ? t('label_issue_template_form') : 'Markdown'}</span>}
      </div>
      {template?.about && <Prose text={template.about} />}
      {!onBack && data.preset && data.preset.length > 0 && <AttrGrid items={data.preset.map((item) => ({ label: item.label, value: item.value }))} />}
    </div>
  );
}
