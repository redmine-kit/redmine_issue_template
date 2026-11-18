import { CardSection, Icon, ListRow, SectionHeading } from '@redmine-kit/ui';
import { useT } from '@redmine-kit/plugin';
import { webUrl, type ChooserData } from './api';

// The template chooser's rows (the new issue's step, and the settings' preview of config.yml): one row per template with
// its tracker, its kind and 「作成を始める」, a blank issue when it is allowed, then config.yml's contact links. Without
// `onChoose` the rows are shown only (a preview).

const hostOf = (url: string) => url.replace(/^https?:\/\//, '').replace(/\/$/, '');

export function ChooserList({ data, onChoose }: { data: ChooserData; onChoose?: (key: string) => void }) {
  const t = useT();
  return (
    <div className="flex min-w-0 flex-col">
      <SectionHeading heading={t('label_issue_template_plural')} count={data.templates.length} inset={24} />
      <div className="flex flex-col">
        {data.templates.map((template) => (
          <ListRow
            key={template.key}
            id={template.key}
            icon={template.kind === 'form' ? 'grid' : 'document'}
            title={template.name}
            sub={template.about || undefined}
            onSelect={onChoose}
            inset={24}
            size={44}
            divider
            cols={[
              { content: template.tracker ?? '', kind: 'text', width: 88 },
              { content: template.kind === 'form' ? t('label_issue_template_form') : 'Markdown', kind: 'muted', width: 72 },
            ]}
            cta={onChoose ? t('label_issue_template_start') : undefined}
          />
        ))}
        {data.blank && (
          <ListRow
            id="blank"
            icon="plus"
            title={t('label_issue_template_blank')}
            sub={t('text_issue_template_blank_info')}
            onSelect={onChoose}
            inset={24}
            size={44}
            cta={onChoose ? t('label_issue_template_start') : undefined}
          />
        )}
      </div>
      {data.contact_links.length > 0 && (
        <CardSection heading={t('label_issue_template_contact_links')} count={data.contact_links.length} inset={24} level={3} className="flex flex-col">
          {data.contact_links.map((link) => (
            <ListRow
              key={link.name + link.url}
              icon="link"
              title={link.name}
              href={onChoose ? webUrl(link.url) : undefined}
              target={onChoose && webUrl(link.url) ? '_blank' : undefined}
              sub={link.about || undefined}
              inset={24}
              size={44}
              cols={[
                { content: hostOf(link.url), kind: 'muted' },
                { content: <Icon name="external" size={13} />, kind: 'muted' },
              ]}
            />
          ))}
        </CardSection>
      )}
    </div>
  );
}
