import { useNewIssueExtension } from '@redmine-kit/plugin';
import type { SectionData } from './api';
import { keepDraft, type Answers } from './answers';
import { TemplateSummary } from './TemplateSummary';

// The template's part at the top of the new issue's form (the manifest's new_issue section, before the tracker's row), as
// the server gives it (KitForm): the template's line with ‹ back to the chooser before its name (the user, 2026-11-12:
// 「『変更』ラベルではなく戻る矢印」) and its description. A YAML form's fields come after the subject
// (IssueTemplateFields); the values the template sets are the form's own fields, shown read-only at their places (the
// part's `locked`), and a form's other fields fold under 「そのほかの項目」 (`fold_attributes`). The server decides
// everything else, as for Redmine's own form: which of the form's fields the user may set, which are required, what the
// answers make of the description, and the checks of the answers (Redmine's messages when the create is refused).
// Going back keeps what was typed into the template (the part's state), so that choosing it again continues it.
// A blank issue: its line only, with ‹.

export function IssueTemplateSection() {
  const { data, params, setParams, state, setState } = useNewIssueExtension<SectionData>();
  const back = () => {
    if (data.template) setState(keepDraft(state, data.template.key, params.issue_template_answers as Answers | undefined, data.elements ?? []));
    setParams({ issue_template: null, issue_template_answers: null, issue_template_uploads: null });
  };
  return <TemplateSummary data={data} onBack={back} />;
}
