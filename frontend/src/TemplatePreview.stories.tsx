import { kitStory, type Meta, type StoryObj } from '@redmine-kit/plugin/storybook';
import { bugFile, configFile, project } from './fixtures';
import { TemplatePreview } from './TemplatePreview';

// プレビュー of a file (KitPreview): what users see with it, drawn with the new issue form's components.
const meta = {
  title: 'Components/TemplatePreview',
  component: TemplatePreview,
  args: { preview: bugFile.preview },
  ...kitStory({ project }),
} satisfies Meta<typeof TemplatePreview>;

export default meta;
type Story = StoryObj<typeof meta>;

/** A template: its chooser row and its new issue's form. */
export const Template: Story = {};

/** config.yml: the chooser it makes. */
export const Config: Story = { args: { preview: configFile.preview } };

/** A file with errors: no preview. */
export const None: Story = { args: { preview: null } };
