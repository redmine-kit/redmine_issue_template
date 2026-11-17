// The plugin's data, as its server gives it: the new issue's form (KitForm, through redmine_kit_ui's hook
// kit_ui_new_issue_form) and the project settings' tab (IssueTemplatesController's JSON, SettingsTab). Paths are this
// server's, built from the context the app gives, with the identifier encoded.

/** A template of the chooser (KitForm#chooser_row). */
export interface TemplateRow {
  key: string;
  name: string;
  /** the chooser's description, as written (Markdown) */
  about: string;
  kind: 'form' | 'markdown';
  tracker: string | null;
}

export interface ContactLink {
  name: string;
  url: string;
  about: string;
}

/** The chooser: the step before the form. */
export interface ChooserData {
  templates: TemplateRow[];
  blank: boolean;
  contact_links: ContactLink[];
}

export interface Option {
  value: string;
  label: string;
  required?: boolean;
}

/** A form's element, with what the form starts with (KitForm#elements). */
export type Element =
  | { type: 'markdown'; text: string }
  | (Field & { type: 'input' | 'textarea'; value: string; render: boolean })
  | (Field & { type: 'dropdown'; multiple: boolean; blank: boolean; options: Option[]; value: string | string[] | null })
  | (Field & { type: 'checkboxes'; options: Option[]; value: string[] })
  | (Field & { type: 'upload'; accept: string[] })
  | (Field & { type: 'link'; kind: 'select' | 'date' | 'textarea' | 'text'; multiple: boolean; options?: Option[]; value: string | string[] | null });

export interface Field {
  ref: string;
  label: string;
  description: string;
  placeholder: string;
  required: boolean;
}

/** The template's part of the form, or a blank issue's line. */
export interface SectionData {
  template?: TemplateRow;
  /** the values the template sets, as text */
  preset?: { label: string; value: string }[];
  elements?: Element[];
  blank?: boolean;
}

/** The settings tab (GET /projects/:id/issue_templates.json). */
export interface SettingsData {
  manual: boolean;
  has_repository: boolean;
  /** where the files come from (none: edited here): the folder, the revision, when (in the user's format), Redmine's pages */
  source: {
    kind: 'repository' | 'github';
    folder: string;
    revision: string | null;
    synced_at: string | null;
    synced_at_text: string | null;
    folder_path?: string;
    revision_path?: string | null;
  } | null;
  errors: boolean;
  /** the name of CommonMark when the text formatting is another */
  text_formatting: string | null;
  files: FileRow[];
  config: { path: string; blank_issues_enabled: boolean; contact_links: ContactLink[] };
  /** the chooser the project's templates make now (config.yml's preview) */
  chooser: ChooserData;
}

export interface FileRow {
  id: number;
  path: string;
  kind: 'config' | 'form' | 'markdown' | '';
  name: string | null;
  tracker: string | null;
  errors: number;
  warnings: number;
}

export interface Message {
  level: 'error' | 'warning';
  text: string;
}

/** What users see with a file (KitPreview): the chooser a config.yml makes, or a template's row and its new issue's form. */
export type Preview =
  | { kind: 'config'; chooser: ChooserData }
  | { kind: 'template'; chooser_row: TemplateRow; issue: { tracker: string | null; subject: string; description: string | null }; section: SectionData };

/** A file (GET /projects/:id/issue_templates/:id.json), with its preview (none when it has errors). */
export interface FileData {
  id: number;
  path: string;
  content: string;
  messages: Message[];
  preview: Preview | null;
}

/** The preview of a file as typed (POST /projects/:id/issue_templates/preview.json). */
export interface PreviewData {
  messages: Message[];
  preview: Preview | null;
}

const base = (project: { identifier: string }) => `/projects/${encodeURIComponent(project.identifier)}/issue_templates`;
export const settingsPath = (project: { identifier: string }) => `${base(project)}.json`;
export const filesPath = settingsPath;
export const filePath = (project: { identifier: string }, id: number | string) => `${base(project)}/${encodeURIComponent(String(id))}.json`;
export const chooserSettingsPath = (project: { identifier: string }) => `${base(project)}/settings.json`;
export const syncPath = (project: { identifier: string }) => `${base(project)}/sync.json`;
export const previewPath = (project: { identifier: string }) => `${base(project)}/preview.json`;
/** the pages the app draws (init.rb's screens) and Redmine's settings tab */
export const newPage = (project: { identifier: string }) => `${base(project)}/new`;
export const editPage = (project: { identifier: string }, id: number) => `${base(project)}/${id}/edit`;
export const tabPage = (project: { identifier: string }) => `/projects/${encodeURIComponent(project.identifier)}/settings/issue_templates`;

/** The format's documentation (ヘルプ). */
export const DOCS = 'https://redmine-kit.github.io/redmine_issue_template/format';

/** A contact link's URL, only when it is a web page (a link of any other scheme stays text). */
export const webUrl = (url: string) => (/^https?:\/\//i.test(url) ? url : undefined);
