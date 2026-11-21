import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { formSection, project } from './fixtures';
import { IssueTemplateSidebar } from './IssueTemplateSidebar';

// The new issue's sidebar (the manifest's new_issue sidebar): where the templates come from, the template's file, the
// fields it hides and the settings tab.
const meta = {
  title: 'New issue/IssueTemplateSidebar',
  component: IssueTemplateSidebar,
  ...kitStory({ project, permissions: ['add_issues'], newIssue: { data: formSection, params: { issue_template: 'bug' } } }),
} satisfies Meta<typeof IssueTemplateSidebar>;

export default meta;
type Story = StoryObj<typeof meta>;

/** Templates from the repository: the folder, the revision, the file and the hidden fields. */
export const Default: Story = {};

/** Templates edited in the project's settings: no repository. */
export const Manual: Story = kitStory({ newIssue: { data: { ...formSection, sidebar: { source: null, path: null, hidden: [], settings_path: '/projects/ecookbook/settings/issue_templates' } }, params: { issue_template: 'bug' } } });
