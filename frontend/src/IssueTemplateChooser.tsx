import { useNewIssueExtension } from '@redmine-kit/plugin';
import type { ChooserData } from './api';
import { ChooserList } from './ChooserList';

// The chooser: the step before the new issue's form (the manifest's new_issue chooser), as the server lists it (KitForm:
// the templates the user may use in the project, a blank issue when config.yml allows it or the user manages templates,
// config.yml's contact links). Choosing one sets issue_template, and the server answers with the template's form. The
// app draws it in place of the form.

export function IssueTemplateChooser() {
  const { data, setParams } = useNewIssueExtension<ChooserData>();
  return <ChooserList data={data} onChoose={(key) => setParams({ issue_template: key, issue_template_answers: null, issue_template_uploads: null })} />;
}
