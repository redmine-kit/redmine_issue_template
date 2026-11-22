import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { fileResponses, project, repositorySource, settings } from './fixtures';
import { IssueTemplateSettings } from './IssueTemplateSettings';

// Project settings › Issue templates (the manifest's project_settings tab): the app's card with the tab's name, the files
// and the chosen one in two panes, ヘルプ, インポート and 新しいテンプレート in the card's header.
const meta = {
  title: 'Settings/IssueTemplateSettings',
  component: IssueTemplateSettings,
  ...kitStory({ frame: 'card', title: 'label_issue_template_plural', project, permissions: ['manage_issue_templates'], responses: fileResponses }),
} satisfies Meta<typeof IssueTemplateSettings>;

export default meta;
type Story = StoryObj<typeof meta>;

/** Templates edited here: the files with their states, the first one's preview. */
export const Default: Story = {};

/** Templates from the repository's folder: read-only here, 取得元 with the revision. */
export const FromRepository: Story = kitStory({
  responses: { ...fileResponses, 'GET /projects/:project_id/issue_templates.json': settings({ manual: false, source: repositorySource, errors: false }) },
});

/** No template yet: the empty list and config.yml's chooser. */
export const Empty: Story = kitStory({
  responses: {
    ...fileResponses,
    'GET /projects/:project_id/issue_templates.json': settings({ files: [], errors: false, chooser: { templates: [], blank: true, contact_links: [] } }),
  },
});

/** A subproject without templates of its own: 共有元 names the parent whose templates it uses (shared with it). */
export const SharedFromParent: Story = kitStory({
  responses: {
    ...fileResponses,
    'GET /projects/:project_id/issue_templates.json': settings({
      files: [], errors: false, sharing: 'none', provider: { name: 'eCookbook', identifier: 'ecookbook' },
      chooser: { templates: [], blank: true, contact_links: [] },
    }),
  },
});

/** The tab still coming: its panes' skeleton. */
export const Loading: Story = kitStory({ state: 'loading' });

/** The tab couldn't be read: the error state with a retry. */
export const Failed: Story = kitStory({ state: 'error' });

/** Redmine refused (no permission manage_issue_templates): 403's error state. */
export const Forbidden: Story = kitStory({ permissions: [], state: 'forbidden' });
