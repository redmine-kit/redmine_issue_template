# Design

Redmine Issue Template adds issue templates to Redmine. "New issue" opens a template chooser, and a template fills in and shapes the issue form. The templates are files in the project's repository, so they are reviewed and versioned with the code, and Redmine imports them when the repository changes.

## Goals

- **Template files in the repository.** Markdown templates, YAML forms and `config.yml`. The files of `.github/ISSUE_TEMPLATE/` are read unchanged.
- **Redmine's own concepts on top.** The tracker (bug, feature…), the priority, the category, the target version, the private flag, custom fields, and which fields of the issue form are shown, hidden or required, are set in the same files.
- **The chooser replaces the first step of "New issue".** Users pick a template before the form, instead of choosing a template inside the form.
- **The repository is the source.** Templates follow the default branch. Projects without a repository keep their templates in the project settings.

## Files

Redmine reads the first of these folders that has template files (`.md`, `.yml`, `.yaml`), on the repository's default branch:

1. `.redmine/ISSUE_TEMPLATE/`
2. `.github/ISSUE_TEMPLATE/`

The folders are not merged: `.redmine/` replaces `.github/`, so that a repository can keep templates for Redmine apart from those in `.github/`.

| File | Kind |
| --- | --- |
| `*.md` | Markdown template: YAML front matter (`name`, `about`, `title`, `labels`, `assignees`, `type`) and the issue body |
| `*.yml`, `*.yaml` | YAML form: `name`, `description`, `body` and the optional `title`, `labels`, `assignees`, `type`, `projects` |
| `config.yml` | Template chooser: `blank_issues_enabled`, `contact_links` |

The chooser lists the templates alphanumerically by file name, YAML forms before Markdown templates.

### Redmine keys

Redmine's keys are top-level keys next to the others, in a Markdown template's front matter or in a YAML form. None of them is a name the other keys use. A YAML form with Redmine's keys goes in `.redmine/ISSUE_TEMPLATE/`; the files of `.github/ISSUE_TEMPLATE/` keep to GitHub's format.

```yaml
tracker: Bug
priority: High
category: UI
fixed_version: "1.0"
is_private: false
custom_fields:
  Severity: Major
fields:
  assigned_to: hidden
  estimated_hours: hidden
  due_date: required
  Severity: required
```

- `tracker`, `priority`, `category`, `fixed_version` are names (or ids) in the project. `is_private` is a boolean. `custom_fields` maps custom field names (or ids) to values.
- `fields` sets each field of the issue form to `shown` (the default), `hidden` or `required`. A hidden field keeps the value the template sets. Fields: `assigned_to`, `category`, `fixed_version`, `parent_issue`, `start_date`, `due_date`, `estimated_hours`, `done_ratio`, `description` (Markdown templates only), `priority`, `is_private`, `watchers`, and custom fields by name or id.

### Other keys

| Key | In Redmine |
| --- | --- |
| `name`, `about` / `description` | The chooser's name and description |
| `title` | The subject the form starts with |
| `type` | The tracker of the same name, unless `tracker` is set |
| `labels` | Not used; reported as a warning |
| `assignees` | The first entry that can be assigned in the project: a user by login, or a group by name when Redmine allows assigning issues to groups (`project.assignable_users`). Other entries are reported as a warning |
| `projects` | No equivalent; reported as a warning |
| Body of a Markdown template | The description the form starts with |
| `body` of a YAML form | The form's fields, shown in place of the description |

### YAML forms

The element types are `markdown`, `textarea` (`label`, `description`, `placeholder`, `value`, `render`; `required`, `min_length`), `input` (`label`, `description`, `placeholder`, `value`; `required`, `min_length`), `dropdown` (`label`, `description`, `multiple`, `options`, `default`; `required`), `checkboxes` (`label`, `description`, options with `label` and `required`; `required`) and `upload` (`label`, `description`; `required`, `accept`). A field with `link` and no `type` sets an issue field ([Links](format.md#links)). Each file is checked as [Checks](format.md#checks) describes.

When the issue is created, the answers become the description in Markdown: a `### <label>` heading per field, the answer below it, `_No response_` when it is empty, a fenced code block for a `textarea` with `render`, the chosen options separated by commas for a `dropdown`, `- [X] <label>` or `- [ ] <label>` per option for `checkboxes`. `upload` is a file field like Redmine's Files field; its files are attached to the issue, and its section lists them. Redmine's own Files field stays below for other files.

Redmine shows descriptions with its text formatting setting. Templates are Markdown, so the setting should be CommonMark Markdown; the project settings tab warns when it is not.

## Import and sync

The project stores the files it uses (`issue_template_files`) and where they came from (`issue_template_sources`: repository, GitHub, or the project settings; the revision; the time; the digest of the files). The errors and warnings are worked out from the stored files when they are shown. Pages read the stored files; they never read the repository.

- **Redmine's repository.** After Redmine fetches the changesets of the project's main repository, the plugin compares the template folder's files with the stored ones, imports them again when they differ, and records the last revision that changed the folder. Any SCM Redmine supports works, through Redmine's own repository adapters. The project settings tab has a button that imports at once.
- **redmine_github.** [Redmine GitHub](https://github.com/redmine-kit/redmine_github) receives GitHub's push events. When a push to the default branch changes `.redmine/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE/`, it calls `RedmineIssueTemplate::Importer.import(project, files:, revision:, source: 'github')` with the folder's files.
- **Project settings.** A project without templates in its repository creates, edits and deletes its files in the project settings, as text in an editor. Saving runs the same input check as an import, and a file with errors is not saved; the errors are shown as Redmine shows form errors. When the repository has templates, they are used, and the settings show them read-only: the file, its content and where it came from. The controller refuses edits to them too.

A file with errors is marked in the settings, with its errors on its page, and left out of the chooser; the other files still work.

## Screens

The screens follow Redmine's own screens ([Redmine Design Guide](https://redmine-kit.github.io/design-guide/)).

- **Template chooser** (`/projects/<id>/issues/templates`): "New issue" opens it when the project has templates. A list like Redmine's lists (`table.list`): the template's name (a link to the form), its description and its tracker. "Blank issue" is an action link, shown when `blank_issues_enabled` is not false, and always to users who can manage the templates. Contact links follow as a second list, "Other contacts". Parameters that came with "New issue" (for example a parent issue) are kept.
- **Issue form**: Redmine's own form, with the template's values. A YAML form's description, tracker, subject and fields are at the top of Redmine's form (the hook `view_issues_form_details_top`, rendered again with the form), in its tabular layout, above a line. Hidden fields, and the fields set by linked fields, are left out of the issue's attributes, and required ones are marked as Redmine marks them.
- **Project settings › Issue templates**: the action links "New template" (without templates in the repository), "Import" and "Help" (the format reference in these docs); where the templates come from, the revision and the time of the last import, as names and values like Administration › Information; the files with an ok or error icon, edited and deleted here when the repository has none; when some files have errors, a notice that they cannot be used; and the settings of config.yml under "Template chooser" (blank issues, other contacts), saved as config.yml when the templates are edited in Redmine and shown read-only otherwise. Each file's page shows its errors and warnings, each as the file, the key and Redmine's validation message.
- **A template file**: the file name links to its page, with where it came from (as on Administration › Information) and its text in a box. "Edit" and "Delete" are there only for files of the project settings. The edit form is a plain text editor (`.box.tabular`, a textarea as on a wiki page) with "Save", "Preview" and "Cancel".
- **Preview**: in a box with the legend "Preview" (as the issue edit page groups its fields), the template's row in the chooser and Redmine's New issue form as the template makes it (values, hidden and required fields, a YAML form's fields), shown but not usable (`inert`). "Preview" on the edit form shows it without saving, after the same input check; the page of a file from a repository always shows it. For `config.yml`, the preview is the chooser with all the templates. Core has no pattern for previewing a template, so this follows the issue form and the lists as they are.

## Permissions

The project module "Issue templates" turns the plugin on for a project. "Manage issue templates" allows the settings tab, editing and importing. The chooser and the forms need "Add issues", as Redmine's own form does.

## Not covered

- Pull request templates and discussion templates.
- `labels` and `projects`, and `type` beyond setting the tracker; they are reported as warnings. Redmine 7.0 has no issue tags (its tags are repository tags); `labels` will set tags once Redmine or a tag plugin provides issue tags.
- Branches other than the default branch.
