import { act, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import type { ChooserData, Element, SectionData } from './api';
import { IssueTemplateChooser } from './IssueTemplateChooser';
import { IssueTemplateFields } from './IssueTemplateFields';
import { IssueTemplateSection } from './IssueTemplateSection';
import { issueTemplateSidebarBlocks } from './IssueTemplateSidebar';
import { JA, renderPart } from './test/render';

// The new issue's part: the chooser, the template's line and a YAML form's fields, with the form's side of the part
// (parameters, state, messages) as the app gives it.

const context = { plugin: 'redmine_kit_issue_template', project: { identifier: 'ecookbook', name: 'eCookbook' } };
const t = (key: string) => JA[key] ?? key;

const ELEMENTS: Element[] = [
  { type: 'markdown', text: 'Thanks for the report.' },
  { type: 'textarea', ref: 'what', label: 'What happened?', description: '', placeholder: '', required: true, value: '', render: '' },
  { type: 'textarea', ref: 'logs', label: 'Logs', description: '', placeholder: '', required: false, value: '', render: 'shell' },
  { type: 'dropdown', ref: 'browsers', label: 'Browsers', description: '', placeholder: '', required: false, multiple: true, blank: true, options: [{ value: '0', label: 'Chrome' }, { value: '1', label: 'Safari' }], value: [] },
  { type: 'checkboxes', ref: 'terms', label: 'Terms', description: '', placeholder: '', required: false, options: [{ value: '0', label: 'I agree', required: true }], value: [] },
  { type: 'link', ref: 'version', label: 'Broken in version', description: '', placeholder: '', required: false, kind: 'select', multiple: false, options: [{ value: '2', label: '1.0' }], value: null, field: '対象バージョン' },
];
const TEMPLATE = { key: 'bug', name: 'Bug report', about: 'Report a bug', kind: 'form' as const, tracker: 'Bug' };
const SECTION: SectionData = { template: TEMPLATE, preset: [{ label: '優先度', value: '高' }], elements: ELEMENTS };
const CHOOSER: ChooserData = {
  templates: [TEMPLATE, { key: 'feature', name: 'Feature request', about: '', kind: 'markdown', tracker: 'Feature' }],
  blank: false,
  contact_links: [],
};

describe("the template's line", () => {
  it('goes back to the chooser with ‹ before the name (no 変更), keeping what was typed into the template', async () => {
    const view = renderPart(<IssueTemplateSection />, { context, data: SECTION, params: { issue_template: 'bug', issue_template_answers: { what: 'It crashed' } } });
    expect(screen.queryByRole('button', { name: '変更' })).toBeNull();
    // the values the template sets are the form's own fields (locked there), not a list here
    expect(screen.queryByText('優先度')).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: 'テンプレートの選択に戻る' }));
    expect(view.form.params).toEqual({});
    expect(view.form.state).toEqual({ drafts: { bug: { what: 'It crashed' } } });
  });

  it('keeps no draft when nothing was changed from what the form starts with', async () => {
    const view = renderPart(<IssueTemplateSection />, { context, data: SECTION, params: { issue_template: 'bug', issue_template_answers: { what: '', logs: '', browsers: [], terms: [] } } });
    await userEvent.click(screen.getByRole('button', { name: 'テンプレートの選択に戻る' }));
    expect(view.form.state).toEqual({ drafts: {} });
  });
});

describe('the chooser', () => {
  it('marks a template with answers 「入力中」 and continues it with them', async () => {
    const view = renderPart(<IssueTemplateChooser />, { context, data: CHOOSER, state: { drafts: { bug: { what: 'It crashed' } } } });
    // the chip in the template's row, after its name (one row: the other has no answers)
    expect(screen.getAllByText('入力中')).toHaveLength(1);
    expect(screen.getByText('入力中').closest('[class*="flex"]')?.parentElement).toHaveTextContent('Bug report');
    await userEvent.click(screen.getByRole('button', { name: 'Bug report' }));
    expect(view.form.params).toEqual({ issue_template: 'bug', issue_template_answers: { what: 'It crashed' } });
  });
});

describe("a YAML form's fields", () => {
  it('a Markdown editor for a textarea, a monospace one with its code block note, a multi-select list, the field a link sets', () => {
    renderPart(<IssueTemplateFields />, { context, data: SECTION, params: { issue_template: 'bug' } });
    // the compact Markdown editor (its toolbar) for the Markdown answer only; the code block's answer is a plain text area
    expect(screen.getAllByRole('toolbar', { name: '書式' })).toHaveLength(1);
    expect(screen.getByText('shell のコードブロックとして記録')).toBeInTheDocument();
    expect(screen.getByRole('combobox', { name: 'Browsers' })).toBeInTheDocument();
    expect(screen.queryByRole('checkbox', { name: 'Chrome' })).toBeNull();
    expect(screen.getByText('対象バージョンに設定')).toBeInTheDocument();
  });

  it('tells the form what is still missing, and shows each message after a click on the disabled 作成', async () => {
    const view = renderPart(<IssueTemplateFields />, { context, data: SECTION, params: { issue_template: 'bug' } });
    await act(async () => undefined);
    expect(view.form.missing).toEqual(['What happened? を入力してください', 'Terms にチェックを入れてください']);
    expect(screen.queryByText('What happened? を入力してください')).toBeNull();
    view.unmount();
    renderPart(<IssueTemplateFields />, { context, data: SECTION, params: { issue_template: 'bug', issue_template_answers: { terms: ['0'] } }, showErrors: true });
    expect(screen.getByText('What happened? を入力してください')).toBeInTheDocument();
    expect(screen.queryByText('Terms にチェックを入れてください')).toBeNull();
  });
});

describe('the sidebar', () => {
  it('where the templates come from with the file, the hidden fields, the settings for a manager', () => {
    const blocks = issueTemplateSidebarBlocks(
      { source: { kind: 'repository', folder: '.redmine/ISSUE_TEMPLATE', revision: 'abc12345', synced_at: null, synced_at_text: '2026/11/19 10:00', folder_path: '/projects/ecookbook/repository' }, path: 'bug.yml', hidden: ['期日'], settings_path: '/projects/ecookbook/settings/issue_templates' },
      t,
    );
    expect(blocks.map((block) => block.key)).toEqual(['source', 'hidden', 'settings']);
    const rows = (blocks[0] as { rows: { over?: string; label: string }[] }).rows;
    expect(rows.map((row) => [row.over, row.label])).toEqual([
      ['リポジトリ', '.redmine/ISSUE_TEMPLATE'],
      ['ファイル', 'bug.yml'],
      ['リビジョン', 'abc12345'],
      ['更新日', '2026/11/19 10:00'],
    ]);
    expect((blocks[2] as { rows: { label: string; href?: string }[] }).rows[0]).toMatchObject({ label: '設定 › チケットテンプレート', href: '/projects/ecookbook/settings/issue_templates' });
  });

  it('templates edited in the project settings, for a user who may not manage them: the source only', () => {
    const blocks = issueTemplateSidebarBlocks({ source: null, path: null, hidden: [], settings_path: null }, t);
    expect(blocks).toHaveLength(1);
    expect((blocks[0] as { rows: { over?: string; label: string }[] }).rows.map((row) => [row.over, row.label])).toEqual([['取得元', 'プロジェクトの設定']]);
  });
});
