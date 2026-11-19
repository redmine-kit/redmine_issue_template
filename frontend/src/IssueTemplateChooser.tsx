import { useNewIssueExtension, useT } from '@redmine-kit/plugin';
import type { ChooserData } from './api';
import { partState } from './answers';
import { ChooserList } from './ChooserList';

// The chooser: the step before the new issue's form (the manifest's new_issue chooser), as the server lists it (KitForm:
// the templates the user may use in the project, a blank issue when config.yml allows it or the user manages templates,
// config.yml's contact links). Choosing one sets issue_template, and the server answers with the template's form. The
// app draws it in place of the form. A template the user typed into before going back (the part's state, while the form
// is open) is marked 「入力中」 and continues with those answers.

export function IssueTemplateChooser() {
  const t = useT();
  const { data, setParams, state } = useNewIssueExtension<ChooserData>();
  const { drafts } = partState(state);
  return (
    <ChooserList
      data={data}
      badgeFor={(key) => (drafts[key] ? t('label_issue_template_draft') : undefined)}
      onChoose={(key) => setParams({ issue_template: key, issue_template_answers: drafts[key] ?? null, issue_template_uploads: null })}
    />
  );
}
