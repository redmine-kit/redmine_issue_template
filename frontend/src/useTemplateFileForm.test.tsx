import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { KitUnsavedChangesGuard } from '@redmine-kit/plugin';
import { settingsPath } from './api';
import { IssueTemplateEdit } from './IssueTemplateEdit';
import { renderKit } from './test/render';

// The template file's form asks before its input is lost (the app's guard, useUnsavedChanges: in the drawer ✕, Esc and a
// click beside it; on the page a move to another page), and lets the move after a save through (allow).
const guard = vi.hoisted(() => ({ dirty: [] as boolean[], allowed: 0 }));
vi.mock('@redmine-kit/plugin', async (original) => ({
  ...(await original<typeof import('@redmine-kit/plugin')>()), // check-ui-ok: a test mocks one hook of the real module
  useUnsavedChanges: (dirty: boolean): KitUnsavedChangesGuard => {
    guard.dirty.push(dirty);
    return { asking: false, stay: () => {}, leave: () => {}, allow: () => void (guard.allowed += 1) };
  },
}));

const project = { identifier: 'ecookbook', name: 'eCookbook' };

beforeEach(() => {
  guard.dirty = [];
  guard.allowed = 0;
});

describe('the template file form’s unsaved input', () => {
  it('is guarded once typed, and the move after 作成 goes through', async () => {
    const user = userEvent.setup();
    renderKit(<IssueTemplateEdit />, { context: { plugin: 'redmine_kit_issue_template', project }, responses: { [`POST ${settingsPath(project)}`]: {} } });
    expect(guard.dirty.at(-1)).toBe(false);
    await user.type(screen.getByRole('textbox', { name: /ファイル名/ }), 'bug.yml');
    expect(guard.dirty.at(-1)).toBe(true);
    expect(guard.allowed).toBe(0);
    await user.click(screen.getByRole('button', { name: /^作成/ }));
    await waitFor(() => expect(guard.allowed).toBe(1));
  });
});
