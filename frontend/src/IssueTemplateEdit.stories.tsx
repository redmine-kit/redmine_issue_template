import { screenStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { fileResponses } from './fixtures';
import { IssueTemplateEdit } from './IssueTemplateEdit';

// A template file's form at its URL (the manifest's /projects/:project_id/issue_templates/new and …/:id/edit; the tab
// opens the same form in a drawer): the file's path and content, and the preview of what users see with it.
const meta = {
  title: 'Screens/IssueTemplateEdit',
  component: IssueTemplateEdit,
  ...screenStory({
    path: '/projects/:project_id/issue_templates/:id/edit',
    route: '/projects/ecookbook/issue_templates/1/edit',
    project: 'eCookbook',
    permissions: ['manage_issue_templates'],
    responses: fileResponses,
  }),
} satisfies Meta<typeof IssueTemplateEdit>;

export default meta;
type Story = StoryObj<typeof meta>;

/** A YAML form's file: its content and its preview. */
export const Edit: Story = {};

/** 新しいテンプレート: an empty file. */
export const New: Story = screenStory({ path: '/projects/:project_id/issue_templates/new', route: '/projects/ecookbook/issue_templates/new' });

/** The file still coming: the form's skeleton. */
export const Loading: Story = screenStory({ state: 'loading' });

/** A file that isn't there: 404's error state. */
export const NotFound: Story = screenStory({ state: 'not-found' });

/** Redmine refused (no permission manage_issue_templates): 403's error state. */
export const Forbidden: Story = screenStory({ permissions: [], state: 'forbidden' });

/** The file couldn't be read: the error state with a retry. */
export const Failed: Story = screenStory({ state: 'error' });
