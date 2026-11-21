import { fn, kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { bugFile, fileResponses, project } from './fixtures';
import { IssueTemplateFileDrawer } from './IssueTemplateFileDrawer';

// The tab's drawer (新しいテンプレート, 編集): the file's form over the tab; its address is the file's page.
const meta = {
  title: 'Components/IssueTemplateFileDrawer',
  component: IssueTemplateFileDrawer,
  args: { project, onClose: fn(), onSaved: fn() },
  ...kitStory({ project, permissions: ['manage_issue_templates'], responses: fileResponses }),
} satisfies Meta<typeof IssueTemplateFileDrawer>;

export default meta;
type Story = StoryObj<typeof meta>;

/** 新しいテンプレート. */
export const New: Story = {};

/** 編集 of a YAML form. */
export const Edit: Story = { args: { file: bugFile } };
