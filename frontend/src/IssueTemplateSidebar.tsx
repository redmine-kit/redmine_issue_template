import type { SidebarBlock } from '@redmine-kit/ui';
import { ScreenSidebar, useNewIssueExtension, useT } from '@redmine-kit/plugin';
import type { ChooserData, SectionData, SidebarData } from './api';
import { sourceRows } from './source';

// The new issue page's sidebar while the templates apply (the manifest's new_issue sidebar: drawn into the page's sidebar
// column with ScreenSidebar), as the server gives it (KitForm#sidebar): チケットテンプレート (where they come from: the
// repository's folder, the revision and when, or the project's settings; the template's file once one applies), テンプレート
// で非表示 (the fields the template hides), and 設定 › チケットテンプレート for a user who manages them. A blank issue: nothing
// (the page's own sidebar, the user's latest issues, stays).

export function issueTemplateSidebarBlocks(sidebar: SidebarData, t: (key: string) => string): SidebarBlock[] {
  const source = sourceRows(sidebar.source, t).map((row) => ({ kind: 'text' as const, key: row.key, over: row.label, label: row.value, href: row.href }));
  const file = sidebar.path ? [{ kind: 'text' as const, key: 'file', over: t('field_filename'), label: sidebar.path }] : [];
  return [
    { key: 'source', label: t('label_issue_template_plural'), rows: [...source.slice(0, 1), ...file, ...source.slice(1)] },
    ...(sidebar.hidden.length
      ? [{ key: 'hidden', label: t('label_issue_template_hidden_fields'), count: sidebar.hidden.length, rows: sidebar.hidden.map((label) => ({ kind: 'text' as const, key: label, label, icon: 'eye-off', muted: true })) }]
      : []),
    ...(sidebar.settings_path ? [{ key: 'settings', rows: [{ key: 'settings', label: t('label_issue_template_settings_link'), icon: 'settings', href: sidebar.settings_path }] }] : []),
  ];
}

export function IssueTemplateSidebar() {
  const t = useT();
  const { data } = useNewIssueExtension<ChooserData & SectionData>();
  if (!data.sidebar || data.blank) return null;
  return <ScreenSidebar label={t('kit.new_issue.sidebar')} groups={issueTemplateSidebarBlocks(data.sidebar, t)} />;
}
