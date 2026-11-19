import { screen } from '@testing-library/react';
import { externalHref } from '@redmine-kit/ui';
import { describe, expect, it } from 'vitest';
import { DOCS } from './api';
import { IssueTemplateEdit } from './IssueTemplateEdit';
import { renderKit } from './test/render';

// A template file's page: beside the form, 形式のヘルプ with ヘルプ, the format's full documentation on another site.

const context = { plugin: 'redmine_kit_issue_template', project: { identifier: 'ecookbook', name: 'eCookbook' } };

describe("the template file's page", () => {
  it('the documentation is an https page of another site: ExternalLink draws it as a link, not as text', () => {
    expect(externalHref(DOCS, 'https://redmine.example/projects/ecookbook')).toBe(DOCS);
  });

  it('ヘルプ: a link to the documentation in a new tab, drawn as the plain button with the external glyph', async () => {
    renderKit(<IssueTemplateEdit />, { context });
    const help = await screen.findByRole('link', { name: /^ヘルプ/ });
    expect(help).toHaveAttribute('href', DOCS);
    expect(help).toHaveAttribute('target', '_blank');
    expect(help).toHaveAttribute('rel', 'noopener noreferrer');
    expect(help).toHaveTextContent('新しいタブで開く');
    expect(help.closest('aside')).toHaveAccessibleName('形式のヘルプ');
    // one glyph: the button's iconEnd (ExternalLink plain draws none of its own)
    expect(help.querySelectorAll('svg')).toHaveLength(1);
    expect(screen.queryByRole('button', { name: /^ヘルプ/ })).toBeNull();
  });
});
