import { screenStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { fileResponses } from './fixtures';
import { IssueTemplateFile } from './IssueTemplateFile';

// A template file's own page (the manifest's /projects/:project_id/issue_templates/:id, Redmine's templates/show): what the
// tab's pane shows of it, at its URL.
const meta = {
  title: 'Screens/IssueTemplateFile',
  component: IssueTemplateFile,
  ...screenStory({
    path: '/projects/:project_id/issue_templates/:id',
    route: '/projects/ecookbook/issue_templates/1',
    project: 'eCookbook',
    permissions: ['manage_issue_templates'],
    responses: fileResponses,
  }),
} satisfies Meta<typeof IssueTemplateFile>;

export default meta;
type Story = StoryObj<typeof meta>;

/** A YAML form: the preview of its chooser row and new issue's form. */
export const Template: Story = {};

/** config.yml: the chooser it makes. */
export const Config: Story = screenStory({ route: '/projects/ecookbook/issue_templates/2' });

/** A file with errors and warnings: its messages, no preview. */
export const WithErrors: Story = screenStory({ route: '/projects/ecookbook/issue_templates/3' });

/** The file still coming: the header's and the pane's skeleton. */
export const Loading: Story = screenStory({ state: 'loading' });

/** A file that isn't there: 404's error state. */
export const NotFound: Story = screenStory({ state: 'not-found' });

/** Redmine refused (no permission manage_issue_templates): 403's error state. */
export const Forbidden: Story = screenStory({ permissions: [], state: 'forbidden' });

/** The file couldn't be read: the error state with a retry. */
export const Failed: Story = screenStory({ state: 'error' });
