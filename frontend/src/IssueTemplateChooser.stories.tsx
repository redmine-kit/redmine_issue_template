import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { chooser, project } from './fixtures';
import { IssueTemplateChooser } from './IssueTemplateChooser';

// The new issue's step (the manifest's new_issue chooser): the project's templates, a blank issue and the contact links.
const meta = {
  title: 'New issue/IssueTemplateChooser',
  component: IssueTemplateChooser,
  ...kitStory({ project, permissions: ['add_issues'], newIssue: { data: chooser } }),
} satisfies Meta<typeof IssueTemplateChooser>;

export default meta;
type Story = StoryObj<typeof meta>;

/** The templates, 空白のチケット and a contact link. */
export const Default: Story = {};

/** Templates only: no blank issue, no contact link. */
export const TemplatesOnly: Story = kitStory({ newIssue: { data: { ...chooser, blank: false, contact_links: [] } } });
