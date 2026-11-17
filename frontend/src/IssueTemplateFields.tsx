import { useEffect } from 'react';
import { useNewIssueExtension, type NewIssueParamValue } from '@redmine-kit/ui';
import type { SectionData } from './api';
import { TemplateQuestions, type AnswerField, type Answers } from './TemplateQuestions';

// A YAML form's fields, after the subject of the new issue's form (the manifest's new_issue sections: after: subject),
// where Redmine's form has the description, which the answers make (KitForm). The answers go with the create as
// issue_template_answers; an upload field's files go with Redmine's own uploads, and issue_template_uploads names them by
// attachment id for each field (the server finds them among the issue's uploads). A Markdown template has none: the
// description is the form's own field, starting with the template's text.

export function IssueTemplateFields() {
  const { data, params, setParams } = useNewIssueExtension<SectionData>();
  const elements = data.elements ?? [];
  const answers = (params.issue_template_answers ?? {}) as Answers;
  const uploads = (params.issue_template_uploads ?? {}) as Record<string, string[]>;
  const fields = elements.filter((element): element is AnswerField => element.type !== 'markdown');
  // the answers the form starts with (the template's values and defaults), once per template
  const starting = JSON.stringify(Object.fromEntries(fields.flatMap((field) => ('value' in field && field.value != null ? [[field.ref, field.value]] : []))));
  useEffect(() => {
    if (params.issue_template_answers === undefined && starting !== '{}') setParams({ issue_template_answers: JSON.parse(starting) as Answers });
  }, [starting, params.issue_template_answers, setParams]);
  return (
    <TemplateQuestions
      elements={elements}
      answers={answers}
      onAnswer={(ref, value) => setParams({ issue_template_answers: { ...answers, [ref]: value } as NewIssueParamValue })}
      onFiles={(ref, files) => setParams({ issue_template_uploads: { ...uploads, [ref]: files.map((file) => file.id) } })}
    />
  );
}
