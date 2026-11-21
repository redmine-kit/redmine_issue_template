import { CardBody, Drawer, DrawerHeader, FormActions } from '@redmine-kit/ui';
import { editPage, newPage, type FileData } from './api';
import { useTemplateFileForm } from './useTemplateFileForm';

// A template file's form in a drawer over the settings tab (新しいテンプレート, a file's 編集), as the app's create and edit
// forms open from their screen; its address is the file's page (IssueTemplateEdit), which shows the same form when it is
// opened directly. A drawer opens over any screen, so its header names the project (ui's docs/architecture/drawers.md
// "The current project's name"), as the app's own drawers and approvals' route drawer do.

export function IssueTemplateFileDrawer({ project, file, onClose, onSaved }: { project: { identifier: string; name: string }; file?: FileData; onClose: () => void; onSaved: (created: boolean) => void }) {
  const form = useTemplateFileForm({ project, file, onSaved, onCancel: onClose });
  const url = file ? editPage(project, file.id) : newPage(project);
  return (
    // every drawer's header (全画面で表示 and 新しいタブで開く: the file's page), one scroll body, the actions as its last row
    <Drawer
      label={form.title}
      onClose={onClose}
      preset="create"
      trapFocus
      url={url}
      header={<DrawerHeader title={form.title} subtitle={project.name} href={url} onClose={onClose} />}
      footer={<FormActions dirty={form.dirty}>{form.actions}</FormActions>}
    >
      {form.bands}
      {/* the form's parts bring their own gutter */}
      <CardBody>{form.body}</CardBody>
    </Drawer>
  );
}
