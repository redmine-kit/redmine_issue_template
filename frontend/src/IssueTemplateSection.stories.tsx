import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { formSection, markdownSection, project } from './fixtures';
import { IssueTemplateSection } from './IssueTemplateSection';

// The template's line at the top of the new issue's form (the manifest's new_issue section), with ‹ back to the chooser.
const meta = {
  title: 'New issue/IssueTemplateSection',
  component: IssueTemplateSection,
  ...kitStory({ project, permissions: ['add_issues'], newIssue: { data: formSection, params: { issue_template: 'bug' } } }),
} satisfies Meta<typeof IssueTemplateSection>;

export default meta;
type Story = StoryObj<typeof meta>;

/** A YAML form's template. */
export const Form: Story = {};

/** A Markdown template. */
export const Markdown: Story = kitStory({ newIssue: { data: markdownSection, params: { issue_template: 'feature' } } });

/** A blank issue (空白のチケット). */
export const Blank: Story = kitStory({ newIssue: { data: { blank: true }, params: { issue_template: 'blank' } } });
