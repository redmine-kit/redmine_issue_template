import { useState } from 'react';
import { screen } from '@testing-library/react';
import { CardHeaderActionsContext } from '@redmine-kit/plugin/host';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import type { FileData, SettingsData } from './api';
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
