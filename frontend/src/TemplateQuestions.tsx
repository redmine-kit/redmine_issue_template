import type { ReactNode } from 'react';
import { Checkbox, CheckboxGroup, DateInput, FormRow, Input, MarkdownEditor, MultiSelect, Prose, Select, Textarea } from '@redmine-kit/ui';
import { NewIssueFileField, useT, type NewIssueFile } from '@redmine-kit/plugin';
import type { Element, Field } from './api';
import type { Answers } from './answers';

// A YAML form's fields, after the subject of the new issue's form (the part's section `IssueTemplateFields`, and the
// settings' preview), drawn with the app's form parts as the server gives them (KitForm#elements: the fields the form
// shows, their options and what they start with):
//   input → Input; textarea → the compact Markdown editor (its answer goes into the description as Markdown), or with
//   `render` a monospace text area, recorded as a code block of that language (the hint says so); dropdown → Select, or
//   MultiSelect with `multiple`; checkboxes → a check box per option; upload → the app's file field (NewIssueFileField:
//   the app uploads the files and sends them with Redmine's own uploads; the form names them by attachment id); a field
//   with a link → the control of the issue's field it sets (a select, a date, a text area, a line), with 「…に設定」.
// `errors` (by ref) shows each field's message, after a click on the disabled 作成.

export type { Answers } from './answers';
export type AnswerField = Exclude<Element, { type: 'markdown' }>;

export interface TemplateQuestionsProps {
  elements: Element[];
  answers: Answers;
  onAnswer?: (ref: string, value: string | string[]) => void;
  /** an upload field's files, once the app has sent them */
  onFiles?: (ref: string, files: NewIssueFile[]) => void;
  /** each field's message, by its ref */
  errors?: Record<string, string>;
}

export function TemplateQuestions({ elements, answers, onAnswer, onFiles, errors = {} }: TemplateQuestionsProps) {
  if (elements.length === 0) return null;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      {elements.map((element, index) =>
        element.type === 'markdown' ? (
          <Prose key={`markdown-${index}`} text={element.text} />
        ) : (
          <FieldRow
            key={element.ref}
            field={element}
            value={answers[element.ref]}
            error={errors[element.ref]}
            onChange={(value) => onAnswer?.(element.ref, value)}
            onFiles={(files) => onFiles?.(element.ref, files)}
          />
        ),
      )}
    </div>
  );
}

const asList = (value: string | string[] | undefined | null) => (Array.isArray(value) ? value : value ? [value] : []);
const asText = (value: string | string[] | undefined | null) => (typeof value === 'string' ? value : '');

interface FieldRowProps {
  field: AnswerField;
  value: string | string[] | undefined;
  error?: string;
  onChange: (value: string | string[]) => void;
  onFiles: (files: NewIssueFile[]) => void;
}

/** One field of a YAML form, with the app's form parts. */
function FieldRow({ field, value, error, onChange, onFiles }: FieldRowProps) {
  const t = useT();
  const note =
    field.type === 'textarea' && field.render
      ? t('text_issue_template_code_block', { lang: field.render })
      : field.type === 'link' && field.field
        ? t('text_issue_template_sets_field', { field: field.field })
        : undefined;
  const row = (control: ReactNode, group = false) => (
    <FormRow layout="stack" label={field.label} required={field.required} hint={hint(field, note)} error={error} group={group}>
      {control}
    </FormRow>
  );
  const blank = { value: '', label: t('actionview_instancetag_blank_option') };
  const placeholder = field.placeholder || undefined;
  switch (field.type) {
    case 'input':
      return row(<Input value={asText(value)} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />);
    case 'textarea':
      // `render`: recorded as a code block, so the plain monospace text area; else Markdown, in the compact editor
      return row(
        field.render ? (
          <Textarea rows={3} mono value={asText(value)} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />
        ) : (
          <MarkdownEditor density="compact" label={field.label} rows={3} maxRows={14} value={asText(value)} placeholder={placeholder} onChange={onChange} />
        ),
      );
    case 'dropdown':
      return field.multiple
        ? row(<MultiSelect className="max-w-80" options={field.options} value={asList(value)} placeholder={blank.label} onValueChange={onChange} />)
        : row(<Select className="max-w-80" label={field.label} options={[...(field.blank ? [blank] : []), ...field.options]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
    case 'checkboxes':
      return row(<Choices options={field.options} value={asList(value)} onChange={onChange} />, true);
    case 'link':
      if (field.kind === 'select')
        return field.multiple
          ? row(<MultiSelect className="max-w-80" options={field.options ?? []} value={asList(value)} placeholder={blank.label} onValueChange={onChange} />)
          : row(<Select className="max-w-80" label={field.label} options={[blank, ...(field.options ?? [])]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
      if (field.kind === 'date') return row(<DateInput value={asText(value)} onChange={(event) => onChange(event.target.value)} />);
      if (field.kind === 'textarea') return row(<Textarea rows={4} value={asText(value)} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />);
      return row(<Input value={asText(value)} placeholder={placeholder} onChange={(event) => onChange(event.target.value)} />);
    case 'upload':
      // the app's field compares extensions with their dot (".png"); a template may write them without it
      return row(<NewIssueFileField name={field.ref} accept={field.accept.length ? field.accept.map((ext) => (ext.startsWith('.') ? ext : `.${ext}`)) : undefined} onChange={onFiles} />, true);
  }
}

/** Checkboxes for the options of a field with several answers. */
function Choices({ options, value, onChange }: { options: { value: string; label: string; required?: boolean }[]; value: string[]; onChange: (value: string[]) => void }) {
  return (
    <CheckboxGroup>
      {options.map((option) => (
        <Checkbox
          key={option.value}
          label={option.required ? `${option.label} *` : option.label}
          checked={value.includes(option.value)}
          onCheckedChange={(checked) => onChange(checked === true ? [...value, option.value] : value.filter((item) => item !== option.value))}
        />
      ))}
    </CheckboxGroup>
  );
}

/** A field's description, as written (Markdown: a link in it is a link), and the form's note on what the answer becomes,
 *  under the field. */
function hint(field: Field, note: string | undefined) {
  if (!field.description && !note) return undefined;
  return (
    <>
      {field.description && <Prose text={field.description} className="text-meta text-text-muted" />}
      {note && <span className="text-meta text-text-muted">{note}</span>}
    </>
  );
}
