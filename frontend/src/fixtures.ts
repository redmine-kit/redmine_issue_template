import type { ChooserData, Element, FileData, SectionData, SettingsData, SidebarData, Source, TemplateRow } from './api';

// The stories' data: the new issue's part as KitForm answers it (through redmine_kit_ui's hook kit_ui_new_issue_form) and
// the settings tab's JSON as TemplatesController answers it (SettingsTab), for the project eCookbook (api.ts). Template
// names, questions and file contents are data, as a project writes them.

export const project = { identifier: 'ecookbook', name: 'eCookbook' };

export const bugTemplate: TemplateRow = { key: 'bug', name: 'Bug report', about: 'Report something that is broken.', kind: 'form', tracker: 'Bug' };
export const featureTemplate: TemplateRow = { key: 'feature', name: 'Feature request', about: 'Suggest an idea for **eCookbook**.', kind: 'markdown', tracker: 'Feature' };

export const elements: Element[] = [
  { type: 'markdown', text: 'Thanks for taking the time to report a bug.' },
  { type: 'textarea', ref: 'what', label: 'What happened?', description: 'Also tell us what you expected.', placeholder: 'Tell us what you see', required: true, value: '', render: '' },
  { type: 'textarea', ref: 'logs', label: 'Logs', description: '', placeholder: '', required: false, value: '', render: 'shell' },
  {
    type: 'dropdown', ref: 'browsers', label: 'Browsers', description: '', placeholder: '', required: false, multiple: true, blank: true,
    options: [{ value: '0', label: 'Chrome' }, { value: '1', label: 'Safari' }, { value: '2', label: 'Firefox' }], value: [],
  },
  { type: 'checkboxes', ref: 'terms', label: 'Code of Conduct', description: '', placeholder: '', required: false, options: [{ value: '0', label: 'I agree to follow the Code of Conduct', required: true }], value: [] },
  { type: 'link', ref: 'version', label: 'Broken in version', description: '', placeholder: '', required: false, kind: 'select', multiple: false, options: [{ value: '2', label: '1.0' }, { value: '3', label: '2.0' }], value: null, field: '対象バージョン' },
];

export const repositorySource: Source = {
  kind: 'repository',
  folder: '.redmine/ISSUE_TEMPLATE',
  revision: 'a1b2c3d',
  synced_at: '2026-11-20T09:30:00+09:00',
  synced_at_text: '2026/11/20 09:30',
  folder_path: '/projects/ecookbook/repository/entry/.redmine/ISSUE_TEMPLATE',
  revision_path: '/projects/ecookbook/repository/revisions/a1b2c3d',
};

export const sidebar: SidebarData = { source: repositorySource, path: '.redmine/ISSUE_TEMPLATE/bug.yml', hidden: ['優先度', '担当者'], settings_path: '/projects/ecookbook/settings/issue_templates' };

/** The new issue's step: the project's templates, a blank issue and a contact link. */
export const chooser: ChooserData = {
  templates: [bugTemplate, featureTemplate],
  blank: true,
  contact_links: [{ name: 'Security issue', url: 'https://example.com/security', about: 'Report a vulnerability privately.' }],
  sidebar,
};

/** The template's part of the form: a YAML form's fields, the values it sets. */
export const formSection: SectionData = { template: bugTemplate, preset: [{ label: '優先度', value: '高め' }], elements, sidebar };
/** A Markdown template's part: its line only. */
export const markdownSection: SectionData = { template: featureTemplate, preset: [], elements: [], sidebar: { ...sidebar, path: '.redmine/ISSUE_TEMPLATE/feature.md', hidden: [] } };

export const bugFile: FileData = {
  id: 1,
  path: 'bug.yml',
  content: 'name: Bug report\ndescription: Report something that is broken.\ntitle: "[Bug]: "\nbody:\n  - type: textarea\n    id: what\n    attributes:\n      label: What happened?\n    validations:\n      required: true\n',
  messages: [],
  preview: { kind: 'template', chooser_row: bugTemplate, issue: { tracker: 'Bug', subject: '[Bug]: ', description: null }, section: formSection },
};

export const configFile: FileData = {
  id: 2,
  path: 'config.yml',
  content: 'blank_issues_enabled: true\ncontact_links:\n  - name: Security issue\n    url: https://example.com/security\n    about: Report a vulnerability privately.\n',
  messages: [],
  preview: { kind: 'config', chooser },
};

export const brokenFile: FileData = {
  id: 3,
  path: 'question.yml',
  content: 'name: Question\nbody: nothing\n',
  messages: [
    { level: 'error', text: 'question.yml: body は配列にしてください' },
    { level: 'warning', text: 'question.yml: labels は無視されます' },
  ],
  preview: null,
};

const files = [bugFile, configFile, brokenFile];

/** GET /projects/:id/issue_templates.json: the templates edited in the project's settings. */
export function settings(patch: Partial<SettingsData> = {}): { issue_templates: SettingsData } {
  return {
    issue_templates: {
      sharing: 'none',
      sharings: ['none', 'descendants', 'hierarchy', 'tree'],
      provider: null,
      shared_files: [],
      manual: true,
      has_repository: true,
      source: null,
      errors: true,
      text_formatting: null,
      files: [
        { id: 2, path: 'config.yml', kind: 'config', name: null, tracker: null, errors: 0, warnings: 0 },
        { id: 1, path: 'bug.yml', kind: 'form', name: 'Bug report', tracker: 'Bug', errors: 0, warnings: 0 },
        { id: 3, path: 'question.yml', kind: 'form', name: 'Question', tracker: null, errors: 1, warnings: 1 },
      ],
      config: { path: 'config.yml', blank_issues_enabled: true, contact_links: chooser.contact_links },
      chooser,
      ...patch,
    },
  };
}

/** Every answer of the settings tab and the file pages. */
export const fileResponses = {
  'GET /projects/:project_id/issue_templates.json': settings(),
  'GET /projects/:project_id/issue_templates/:id.json': ({ params }: { params: Record<string, unknown> }) => ({ issue_template_file: files.find((file) => String(file.id) === params.id) ?? bugFile }),
  'POST /projects/:project_id/issue_templates/preview.json': { messages: [], preview: bugFile.preview },
};
