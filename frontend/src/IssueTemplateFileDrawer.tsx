import { CardBody, CardHeader, Drawer, DrawerActionsGroup, DrawerCloseButton, FormActions } from '@redmine-kit/ui';
import { editPage, newPage, type FileData } from './api';
import { useTemplateFileForm } from './useTemplateFileForm';

// A template file's form in a drawer over the settings tab (新しいテンプレート, a file's 編集), as the app's create and edit
// forms open from their screen; its address is the file's page (IssueTemplateEdit), which shows the same form when it is
// opened directly. A drawer opens over any screen, so its header names the project (ui's docs/decisions/drawers.md
// "The current project's name"), as the app's own drawers and approvals' route drawer do.

export function IssueTemplateFileDrawer({ project, file, onClose, onSaved }: { project: { identifier: string; name: string }; file?: FileData; onClose: () => void; onSaved: (created: boolean) => void }) {
  const form = useTemplateFileForm({ project, file, onSaved, onCancel: onClose });
  return (
    <Drawer label={form.title} onClose={onClose} preset="create" trapFocus url={file ? editPage(project, file.id) : newPage(project)}>
      <CardHeader
        title={form.title}
        subtitle={project.name}
        divider
        actions={
          <DrawerActionsGroup>
            <DrawerCloseButton onClose={onClose} />
          </DrawerActionsGroup>
        }
      />
      {form.bands}
      <CardBody>
        {form.body}
        <FormActions placement="sticky" edge dirty={form.dirty}>
          {form.actions}
        </FormActions>
      </CardBody>
    </Drawer>
  );
}
