import { CardSection, Icon, ListRow, SectionHeading, useNewIssueExtension, useT } from '@redmine-kit/ui';
import { webUrl, type ChooserData } from './api';

// The chooser: the step before the new issue's form (the manifest's new_issue chooser), as the server lists it (KitForm:
// the templates the user may use in the project, a blank issue when config.yml allows it or the user manages templates,
// config.yml's contact links). One row per template with its tracker, its kind and 「作成を始める」; choosing one sets
// issue_template, and the server answers with the template's form. The app draws it in place of the form.

const hostOf = (url: string) => url.replace(/^https?:\/\//, '').replace(/\/$/, '');

export function IssueTemplateChooser() {
  const t = useT();
  const { data, setParams } = useNewIssueExtension<ChooserData>();
  const choose = (key: string) => setParams({ issue_template: key, issue_template_answers: null });
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
            onSelect={choose}
            inset={24}
            size={44}
            divider
            cols={[
              { content: template.tracker ?? '', kind: 'text', width: 88 },
              { content: template.kind === 'form' ? t('label_issue_template_form') : 'Markdown', kind: 'muted', width: 72 },
            ]}
            cta={t('label_issue_template_start')}
          />
        ))}
        {data.blank && (
          <ListRow
            id="blank"
            icon="plus"
            title={t('label_issue_template_blank')}
            sub={t('text_issue_template_blank_info')}
            onSelect={choose}
            inset={24}
            size={44}
            cta={t('label_issue_template_start')}
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
              href={webUrl(link.url)}
              target={webUrl(link.url) ? '_blank' : undefined}
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
