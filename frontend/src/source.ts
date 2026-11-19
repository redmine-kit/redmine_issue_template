import type { Source } from './api';

// Where the templates come from, as rows of a label and a value: the settings tab's 取得元 and the new issue's sidebar
// draw the same rows. Edited in the project's settings: 取得元 プロジェクトの設定. From a repository or GitHub: the folder
// (with the repository's page of it), the revision it was imported from and when.

export interface SourceRow {
  key: string;
  label: string;
  value: string;
  href?: string;
}

export function sourceRows(source: Source | null, t: (key: string) => string): SourceRow[] {
  if (!source) return [{ key: 'source', label: t('label_issue_template_source'), value: t('label_issue_template_project_settings') }];
  return [
    { key: 'source', label: source.kind === 'github' ? 'GitHub' : t('label_repository'), value: source.folder, href: source.folder_path },
    ...(source.revision ? [{ key: 'revision', label: t('label_revision'), value: source.revision, href: source.revision_path ?? undefined }] : []),
    ...(source.synced_at_text ? [{ key: 'updated', label: t('field_updated_on'), value: source.synced_at_text }] : []),
  ];
}
