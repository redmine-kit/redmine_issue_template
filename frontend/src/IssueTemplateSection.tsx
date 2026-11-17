import { useEffect, type ReactNode } from 'react';
import { AttrGrid, Button, Checkbox, CheckboxGroup, FormRow, Icon, Input, Notice, Prose, Select, Textarea, useNewIssueExtension, useT, type NewIssueParamValue } from '@redmine-kit/ui';
import type { Element, Field, SectionData } from './api';

// The template's part of the new issue's form (the manifest's new_issue section), at the top of the app's form, as the
// server gives it (KitForm): the template's line (its kind, its name, 変更 back to the chooser), its description, the
// values it sets (as text: the form can't change them), and a YAML form's fields, whose answers go with the create as
// issue_template_answers. The server decides everything else, as for Redmine's own form: which of the form's fields the
// user may set (the template's hidden, preset and linked fields are left out of the form), which are required, what the
// answers make of the description, and the checks of the answers (Redmine's messages when the create is refused).
// A blank issue: its line only, with 変更.

type Answers = Record<string, string | string[]>;

export function IssueTemplateSection() {
  const t = useT();
  const { data, params, setParams } = useNewIssueExtension<SectionData>();
  const change = () => setParams({ issue_template: null, issue_template_answers: null });
  const answers = (params.issue_template_answers ?? {}) as Answers;
  const fields = (data.elements ?? []).filter((element): element is Exclude<Element, { type: 'markdown' }> => element.type !== 'markdown');
  // the answers the form starts with (the template's values and defaults), once per template
  const starting = JSON.stringify(Object.fromEntries(fields.flatMap((field) => ('value' in field && field.value != null ? [[field.ref, field.value]] : []))));
  useEffect(() => {
    if (params.issue_template_answers === undefined && starting !== '{}') setParams({ issue_template_answers: JSON.parse(starting) as Answers });
  }, [starting, params.issue_template_answers, setParams]);
  const answer = (ref: string, value: string | string[]) => setParams({ issue_template_answers: { ...answers, [ref]: value } as NewIssueParamValue });

  const template = data.template;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      <div className="flex min-h-8 min-w-0 items-center gap-2.5">
        <Icon name={data.blank ? 'plus' : template?.kind === 'form' ? 'grid' : 'document'} size={16} />
        <span className="min-w-0 truncate font-medium">{data.blank ? t('label_issue_template_blank') : template?.name}</span>
        {template && <span className="flex-none text-meta text-text-muted">{template.kind === 'form' ? t('label_issue_template_form') : 'Markdown'}</span>}
        <span className="flex-1" />
        <Button size={28} variant="ghost" onClick={change}>
          {t('button_change')}
        </Button>
      </div>
      {template?.about && <Prose text={template.about} />}
      {data.preset && data.preset.length > 0 && <AttrGrid items={data.preset.map((item) => ({ label: item.label, value: item.value }))} />}
      {(data.elements ?? []).map((element, index) =>
        element.type === 'markdown' ? (
          <Prose key={`markdown-${index}`} text={element.text} />
        ) : (
          <FieldRow key={element.ref} field={element} value={answers[element.ref]} onChange={(value) => answer(element.ref, value)} />
        ),
      )}
    </div>
  );
}

const asList = (value: string | string[] | undefined | null) => (Array.isArray(value) ? value : value ? [value] : []);
const asText = (value: string | string[] | undefined | null) => (typeof value === 'string' ? value : '');

/** One field of a YAML form, with the app's form parts. */
function FieldRow({ field, value, onChange }: { field: Exclude<Element, { type: 'markdown' }>; value: string | string[] | undefined; onChange: (value: string | string[]) => void }) {
  const t = useT();
  const row = (control: ReactNode) => (
    <FormRow layout="stack" label={field.label} required={field.required} hint={hint(field)}>
      {control}
    </FormRow>
  );
  switch (field.type) {
    case 'input':
      return row(<Input value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'textarea':
      return row(<Textarea rows={4} mono={field.render} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'dropdown':
      return field.multiple
        ? row(<Choices options={field.options} value={asList(value)} onChange={onChange} />)
        : row(<Select label={field.label} options={[...(field.blank ? [{ value: '', label: t('actionview_instancetag_blank_option') }] : []), ...field.options]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
    case 'checkboxes':
      return row(<Choices options={field.options} value={asList(value)} onChange={onChange} />);
    case 'link':
      if (field.kind === 'select')
        return field.multiple
          ? row(<Choices options={field.options ?? []} value={asList(value)} onChange={onChange} />)
          : row(<Select label={field.label} options={[{ value: '', label: t('actionview_instancetag_blank_option') }, ...(field.options ?? [])]} value={asText(value)} onValueChange={(next) => onChange(next)} />);
      if (field.kind === 'textarea') return row(<Textarea rows={4} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
      return row(<Input type={field.kind === 'date' ? 'date' : 'text'} value={asText(value)} placeholder={field.placeholder || undefined} onChange={(event) => onChange(event.target.value)} />);
    case 'upload':
      return row(<Notice tone="warning" inset={0} wrap text={t('text_issue_template_upload_unavailable')} />);
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

/** A field's description, and the extensions an upload field takes. */
function hint(field: Field & { accept?: string[] }) {
  return [field.description, field.accept?.length ? field.accept.join(', ') : ''].filter(Boolean).join(' · ') || undefined;
}
