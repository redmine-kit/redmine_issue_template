import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { KitTestRequest } from '@redmine-kit/plugin/testing';
import { describe, expect, it } from 'vitest';
import type { FileData, SettingsData } from './api';
import { IssueTemplateFile } from './IssueTemplateFile';
import { IssueTemplateFileDrawer } from './IssueTemplateFileDrawer';
import { renderKit } from './test/render';

// A template file's own page (issue_templates/show's URL) and the file's form in a drawer: the page shows what the tab's
// pane shows of the file, with 編集 and 削除 only when the templates are edited here; the drawer names the project, as a
// drawer over any screen does (ui's docs/architecture/drawers.md "The current project's name").

const MANAGED_ELSEWHERE = 'テンプレートは取得元で編集してください。';
const project = { identifier: 'ecookbook', name: 'eCookbook' };
const context = { plugin: 'redmine_kit_issue_template', project, params: { id: '1' } };
const FILE: FileData = { id: 1, path: 'bug.md', content: '# Bug', messages: [{ level: 'warning', text: 'bug.md: labels は無視されます' }], preview: null };
const settings = (manual: boolean) =>
  ({ manual, has_repository: true, source: null, errors: false, text_formatting: null, files: [], config: { path: 'config.yml', blank_issues_enabled: true, contact_links: [] }, chooser: { templates: [], blank: true, contact_links: [] } }) as SettingsData;
const responses = (manual: boolean) => ({
  'GET /projects/ecookbook/issue_templates/1.json': { issue_template_file: FILE },
  'GET /projects/ecookbook/issue_templates.json': { issue_templates: settings(manual) },
  'DELETE /projects/ecookbook/issue_templates/1.json': {},
});


/** The form's one scroll body (CardBody: a bounded flex item that scrolls) holds the field and, last, the sticky actions. */
function expectOneScrollBody(field: HTMLElement, action: HTMLElement) {
  const body = field.closest<HTMLElement>('.overflow-y-auto');
  expect(body).not.toBeNull();
  expect(body!.className).toMatch(/\bmin-h-0\b/);
  expect(body!.className).toMatch(/\bflex-1\b/);
  expect(body).toContainElement(action);
  const actions = action.closest<HTMLElement>('.sticky');
  expect(actions).not.toBeNull();
  expect(actions!.className).toMatch(/\bbottom-0\b/);
  expect(body!.lastElementChild).toBe(actions);
}

describe("a template file's page", () => {
  it("the file's name in the header, its messages and its preview and content, 編集 and 削除 when edited here", async () => {
    const requests: KitTestRequest[] = [];
    renderKit(<IssueTemplateFile />, { context, requests, responses: responses(true) });
    expect(await screen.findByRole('heading', { name: 'bug.md' })).toBeInTheDocument();
    expect(screen.getByText('bug.md: labels は無視されます')).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: 'プレビュー' })).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: '編集' })).toBeInTheDocument();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: '削除' }));
    await user.click(within(await screen.findByRole('dialog')).getByRole('button', { name: '削除' }));
    await waitFor(() => expect(requests.some((r) => r.method === 'delete' && r.path === '/projects/ecookbook/issue_templates/1.json')).toBe(true));
  });

  it('no 編集 or 削除 when the templates come from elsewhere', async () => {
    renderKit(<IssueTemplateFile />, { context, responses: responses(false) });
    expect(await screen.findByRole('heading', { name: 'bug.md' })).toBeInTheDocument();
    // once the tab's answer says where they are edited
    expect(await screen.findByText(MANAGED_ELSEWHERE)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '編集' })).toBeNull();
    expect(screen.queryByRole('button', { name: '削除' })).toBeNull();
  });
});

describe("the file's drawer", () => {
  it('scrolls in one body, its actions sticky at the foot (a long template)', async () => {
    renderKit(<IssueTemplateFileDrawer project={project} file={FILE} onClose={() => {}} onSaved={() => {}} />, { context, responses: responses(true) });
    const dialog = await screen.findByRole('dialog');
    const save = await within(dialog).findByRole('button', { name: /保存/ });
    expectOneScrollBody(within(dialog).getByRole('tablist'), save);
  });

  it('names the project under its title', async () => {
    renderKit(<IssueTemplateFileDrawer project={project} file={FILE} onClose={() => {}} onSaved={() => {}} />, { context, responses: responses(true) });
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText('eCookbook')).toBeInTheDocument();
  });
});
