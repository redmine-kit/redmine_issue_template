import type { Element } from './api';

// A YAML form's answers: what the form starts with, what the user typed into each template while the form is open (kept
// in the part's state, so that going back to the chooser and choosing the template again continues it: 「入力中」 on the
// chooser), and what is still missing before the create (Redmine's sentences).

export type Answers = Record<string, string | string[]>;

/** The part's state while the form is open: each template's answers the user typed (by the template's key). */
export interface PartState {
  drafts: Record<string, Answers>;
}

export const partState = (state: unknown): PartState => {
  const drafts = (state as PartState | undefined)?.drafts;
  return { drafts: drafts && typeof drafts === 'object' ? drafts : {} };
};

/** The answers the form starts with (the template's values and defaults). */
export const startingAnswers = (elements: Element[]): Answers =>
  Object.fromEntries(elements.flatMap((element) => (element.type !== 'markdown' && element.type !== 'upload' && 'value' in element && element.value != null ? [[element.ref, element.value]] : [])));

const same = (a: Answers, b: Answers) => JSON.stringify(Object.entries(a).sort()) === JSON.stringify(Object.entries(b).sort());

/** The state after leaving a template: its answers kept when the user changed something, else none. */
export function keepDraft(state: unknown, key: string, answers: Answers | undefined, elements: Element[]): PartState {
  const { drafts } = partState(state);
  const { [key]: _old, ...others } = drafts;
  return { drafts: answers && !same(answers, startingAnswers(elements)) ? { ...others, [key]: answers } : others };
}

const empty = (value: string | string[] | undefined) => (Array.isArray(value) ? value.length === 0 : !value?.trim());

/** What the answers still need, as the server's check words it (IssueTemplateAnswers: the field's label, the plugin's
 *  separator, Redmine's message): each required field left empty, a required checkbox unchecked, by the field's ref.
 *  Upload fields are the server's to check (their files arrive with the create). */
export function answerErrors(elements: Element[], answers: Answers, t: (key: string) => string): Record<string, string> {
  const message = (label: string, key: string) => `${label}${t('issue_template_error_separator')}${t(key)}`;
  const errors: Record<string, string> = {};
  elements.forEach((element) => {
    if (element.type === 'markdown' || element.type === 'upload') return;
    const value = answers[element.ref];
    if (element.type === 'checkboxes') {
      const checked = Array.isArray(value) ? value : [];
      if (element.options.some((option) => option.required && !checked.includes(option.value))) errors[element.ref] = message(element.label, 'issue_template_error_unchecked');
      return;
    }
    if (element.required && empty(value)) errors[element.ref] = message(element.label, 'activerecord.errors.messages.blank');
  });
  return errors;
}
