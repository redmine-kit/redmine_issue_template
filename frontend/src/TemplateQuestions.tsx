import type { ReactNode } from 'react';
import { Checkbox, CheckboxGroup, FormRow, Input, NewIssueFileField, Prose, Select, Textarea, useT, type NewIssueFile } from '@redmine-kit/ui';
import type { Element, Field } from './api';

// A YAML form's fields, after the subject of the new issue's form (the part's section `IssueTemplateFields`, and the
// settings' preview), drawn with the app's form parts as the server gives them (KitForm#elements: the fields the form
// shows, their options and what they start with). An upload field is the app's file field (NewIssueFileField): the app
// uploads the files and sends them with Redmine's own uploads; the form names them by attachment id.

export type Answers = Record<string, string | string[]>;
export type AnswerField = Exclude<Element, { type: 'markdown' }>;

export interface TemplateQuestionsProps {
  elements: Element[];
  answers: Answers;
  onAnswer?: (ref: string, value: string | string[]) => void;
  /** an upload field's files, once the app has sent them */
  onFiles?: (ref: string, files: NewIssueFile[]) => void;
}

export function TemplateQuestions({ elements, answers, onAnswer, onFiles }: TemplateQuestionsProps) {
  if (elements.length === 0) return null;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      {elements.map((element, index) =>
        element.type === 'markdown' ? (
          <Prose key={`markdown-${index}`} text={element.text} />
        ) : (
          <FieldRow key={element.ref} field={element} value={answers[element.ref]} onChange={(value) => onAnswer?.(element.ref, value)} onFiles={(files) => onFiles?.(element.ref, files)} />
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
  onChange: (value: string | string[]) => void;
  onFiles: (files: NewIssueFile[]) => void;
}

/** One field of a YAML form, with the app's form parts. */
function FieldRow({ field, value, onChange, onFiles }: FieldRowProps) {
  const t = useT();
  const row = (control: ReactNode) => (
    <FormRow layout="stack" label={field.label} required={field.required} hint={hint(field)}>
      {control}
    </FormRow>
  );
  const blank = { value: '', label: t('actionview_instancetag_blank_option') };
  switch (field.type) {
    case 'input':
      return row(<Input value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'textarea':
      return row(<Textarea rows={4} mono={field.render} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'dropdown':
      return field.multiple
        ? row(<Choices options={field.options} value={asList(value)} onChange={onChange} />)
        : row(<Select label={field.label} options={[...(field.blank ? [blank] : []), ...field.options]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
    case 'checkboxes':
      return row(<Choices options={field.options} value={asList(value)} onChange={onChange} />);
    case 'link':
      if (field.kind === 'select')
        return field.multiple
          ? row(<Choices options={field.options ?? []} value={asList(value)} onChange={onChange} />)
          : row(<Select label={field.label} options={[blank, ...(field.options ?? [])]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
      if (field.kind === 'textarea') return row(<Textarea rows={4} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
      return row(<Input type={field.kind === 'date' ? 'date' : 'text'} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'upload':
      // the app's field compares extensions with their dot (".png"); a template may write them without it
      return row(<NewIssueFileField name={field.ref} accept={field.accept.length ? field.accept.map((ext) => (ext.startsWith('.') ? ext : `.${ext}`)) : undefined} onChange={onFiles} />);
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

/** A field's description, as written (Markdown: a link in it is a link), under the field; the upload field's extensions are
 *  the file field's own. */
function hint(field: Field) {
  return field.description ? <Prose text={field.description} className="text-meta text-text-muted" /> : undefined;
}
