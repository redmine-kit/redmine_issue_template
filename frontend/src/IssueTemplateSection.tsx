import { useNewIssueExtension } from '@redmine-kit/ui';
import type { SectionData } from './api';
import { TemplateSummary } from './TemplateSummary';

// The template's part at the top of the new issue's form (the manifest's new_issue section, before the tracker's row), as
// the server gives it (KitForm): the template's line with 変更 back to the chooser, its description and the values it
// sets. A YAML form's fields come after the subject (IssueTemplateFields). The server decides everything else, as for
// Redmine's own form: which of the form's fields the user may set (the template's hidden, preset and linked fields are
// left out of the form), which are required, what the answers make of the description, and the checks of the answers
// (Redmine's messages when the create is refused). A blank issue: its line only, with 変更.

export function IssueTemplateSection() {
  const { data, setParams } = useNewIssueExtension<SectionData>();
  return <TemplateSummary data={data} onChange={() => setParams({ issue_template: null, issue_template_answers: null, issue_template_uploads: null })} />;
}
