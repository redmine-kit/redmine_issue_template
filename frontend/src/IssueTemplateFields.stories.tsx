import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { formSection, project } from './fixtures';
import { IssueTemplateFields } from './IssueTemplateFields';

// A YAML form's fields after the subject (the manifest's new_issue sections): its text, questions, choices and the field
// it links to.
const meta = {
  title: 'New issue/IssueTemplateFields',
  component: IssueTemplateFields,
  ...kitStory({ project, permissions: ['add_issues'], newIssue: { data: formSection, params: { issue_template: 'bug' } } }),
} satisfies Meta<typeof IssueTemplateFields>;

export default meta;
type Story = StoryObj<typeof meta>;

/** The form's questions as the form starts. */
export const Default: Story = {};

/** The answers so far (a draft kept in the part's parameters). */
export const Answered: Story = kitStory({
  newIssue: { data: formSection, params: { issue_template: 'bug', issue_template_answers: { what: 'The page goes blank after sign-in.', browsers: ['0', '1'] } } },
});
