import { useEffect, useRef } from 'react';
import { useNewIssueExtension, useT, type NewIssueParamValue } from '@redmine-kit/plugin';
import type { SectionData } from './api';
import { answerErrors, startingAnswers, type Answers } from './answers';
import { TemplateQuestions } from './TemplateQuestions';

// A YAML form's fields, after the subject of the new issue's form (the manifest's new_issue sections: after: subject),
// where Redmine's form has the description, which the answers make (KitForm). The answers go with the create as
// issue_template_answers; an upload field's files go with Redmine's own uploads, and issue_template_uploads names them by
// attachment id for each field (the server finds them among the issue's uploads). What the answers still need (a
// required field left empty, a required checkbox) goes to the form, so that 作成 waits and names it, and each field shows
// its message after a click on the disabled 作成; the server checks the answers again on the create. A Markdown
// template has none: the description is the form's own field, starting with the template's text.

export function IssueTemplateFields() {
  const t = useT();
  const { data, params, setParams, setMissing, showErrors } = useNewIssueExtension<SectionData>();
  const elements = data.elements ?? [];
  const answers = (params.issue_template_answers ?? {}) as Answers;
  const uploads = (params.issue_template_uploads ?? {}) as Record<string, string[]>;
  // the answers the form starts with (the template's values and defaults), once per template
  const starting = JSON.stringify(startingAnswers(elements));
  useEffect(() => {
    if (params.issue_template_answers === undefined && starting !== '{}') setParams({ issue_template_answers: JSON.parse(starting) as Answers });
  }, [starting, params.issue_template_answers, setParams]);
  const errors = answerErrors(elements, answers, t);
  // the form's messages follow the answers; none once the fields are gone (another template, the chooser)
  const messages = JSON.stringify(Object.values(errors));
  const tell = useRef(setMissing);
  useEffect(() => {
    tell.current = setMissing;
  });
  useEffect(() => {
    tell.current(JSON.parse(messages) as string[]);
  }, [messages]);
  useEffect(
    () => () => {
      tell.current([]);
    },
    [],
  );
  return (
    <TemplateQuestions
      elements={elements}
      answers={answers}
      errors={showErrors ? errors : undefined}
      onAnswer={(ref, value) => setParams({ issue_template_answers: { ...answers, [ref]: value } as NewIssueParamValue })}
      onFiles={(ref, files) => setParams({ issue_template_uploads: { ...uploads, [ref]: files.map((file) => file.id) } })}
    />
  );
}
