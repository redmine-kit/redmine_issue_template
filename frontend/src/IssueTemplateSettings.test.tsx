import { useState } from 'react';
import { screen, waitFor, within } from '@testing-library/react';
import { ApiError } from '@redmine-kit/plugin';
import { CardHeaderActionsContext } from '@redmine-kit/plugin/host';
import type { KitTestRequest } from '@redmine-kit/plugin/testing';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { DOCS, type FileData, type SettingsData } from './api';
import { IssueTemplateSettings } from './IssueTemplateSettings';
import { renderKit } from './test/render';

// Project settings › Issue templates: where the templates come from, the import's tip, the files' messages with their
// headings, and the chooser's settings (the blank issue's description, what saving does).

const context = { plugin: 'redmine_kit_issue_template', project: { identifier: 'ecookbook', name: 'eCookbook' } };
const CHOOSER = { templates: [], blank: true, contact_links: [] };
const settings = (patch: Partial<SettingsData> = {}): SettingsData => ({
  manual: true,
  has_repository: true,
  source: null,
  errors: false,
  text_formatting: null,
  files: [{ id: 1, path: 'bug.yml', kind: 'form', name: 'Bug report', tracker: 'Bug', errors: 1, warnings: 1 }],
  config: { path: 'config.yml', blank_issues_enabled: true, contact_links: [] },
  chooser: CHOOSER,
  ...patch,
});
const FILE: FileData = {
  id: 1,
  path: 'bug.yml',
  content: 'name: Bug report',
  messages: [
    { level: 'error', text: 'bug.yml: body は不明なキーです' },
    { level: 'warning', text: 'bug.yml: labels は無視されます' },
  ],
  preview: null,
};
const responses = (data: SettingsData) => ({
  'GET /projects/ecookbook/issue_templates.json': { issue_templates: data },
  'GET /projects/ecookbook/issue_templates/1.json': { issue_template_file: FILE },
});

/** The tab in the app's card: its header's actions (CardHeaderActions) go to the header. */
function InCard() {
  const [header, setHeader] = useState<HTMLElement | null>(null);
  return (
    <>
      <div ref={setHeader} role="toolbar" aria-label="header" />
      <CardHeaderActionsContext value={header}>
        <IssueTemplateSettings />
      </CardHeaderActionsContext>
    </>
  );
}

describe('the settings tab', () => {
  it('templates edited here: 取得元 プロジェクトの設定; the import says what it does', async () => {
    renderKit(<InCard />, { context, responses: responses(settings()) });
    expect(await screen.findByText('プロジェクトの設定')).toBeInTheDocument();
    expect(screen.getAllByText('取得元').length).toBeGreaterThan(0);
    await userEvent.hover(screen.getByRole('button', { name: 'インポート' }));
    expect((await screen.findAllByText('取得を待たずに、リポジトリのテンプレートフォルダーを読み込みます')).length).toBeGreaterThan(0);
  });

  it("ヘルプ in the card's header: a link to the format's documentation in a new tab, drawn as the button", async () => {
    renderKit(<InCard />, { context, responses: responses(settings()) });
    const header = screen.getByRole('toolbar', { name: 'header' });
    const help = await within(header).findByRole('link', { name: /^ヘルプ/ });
    expect(help).toHaveAttribute('href', DOCS);
    expect(help).toHaveAttribute('target', '_blank');
    expect(help).toHaveAttribute('rel', 'noopener noreferrer');
    expect(help).toHaveTextContent('新しいタブで開く');
    // Button asChild: the button's look and its glyph on the link, no button of its own
    expect(help.className).toMatch(/\binline-flex\b/);
    expect(help.querySelector('svg')).not.toBeNull();
    expect(within(header).queryByRole('button', { name: /^ヘルプ/ })).toBeNull();
  });

  it("a file's messages with their headings: エラー and 警告", async () => {
    renderKit(<IssueTemplateSettings />, { context, responses: responses(settings()) });
    const error = await screen.findByText('bug.yml: body は不明なキーです');
    expect(error.closest('[role], div')?.parentElement).toHaveTextContent('エラー');
    expect(screen.getByText('bug.yml: labels は無視されます').closest('[role], div')?.parentElement).toHaveTextContent('警告');
  });

  it("the chooser's settings: the blank issue's description and what saving does", async () => {
    renderKit(<IssueTemplateSettings />, { context, responses: responses(settings({ files: [] })) });
    expect(await screen.findByText('テンプレートを使わずにチケットを作成できます。チケットテンプレートの管理の権限があるユーザーは、常に作成できます。')).toBeInTheDocument();
    expect(screen.getByText('保存すると config.yml を作り直します')).toBeInTheDocument();
  });
});

describe('the settings tab that couldn’t load', () => {
  it.each([
    [403, 'notice_not_authorized'],
    [404, 'notice_file_not_found'],
  ])('%i: Redmine’s refusal, no 再読み込み', async (status, title) => {
    renderKit(<InCard />, { context, responses: { 'GET /projects/ecookbook/issue_templates.json': new ApiError(status, []) } });
    expect(await screen.findByRole('heading', { name: new RegExp(title) })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'kit.error.reload' })).toBeNull();
  });

  it('another failure: 再読み込み reads the tab again', async () => {
    const requests: KitTestRequest[] = [];
    renderKit(<InCard />, { context, requests, responses: { 'GET /projects/ecookbook/issue_templates.json': new ApiError(500, []) } });
    await userEvent.click(await screen.findByRole('button', { name: 'kit.error.reload' }));
    await waitFor(() => expect(requests.filter((r) => r.path === '/projects/ecookbook/issue_templates.json')).toHaveLength(2));
  });
});
