# Design

Redmine Issue Template brings GitHub's issue templates to Redmine. "New issue" opens a template chooser, as on GitHub, and a template fills in and shapes the issue form. The templates are files in the project's repository, so they are reviewed and versioned with the code, and Redmine imports them when the repository changes.

## Goals

- **The same files as GitHub.** Markdown issue templates, YAML issue forms and `config.yml`, as GitHub defines them, work unchanged. A repository that already has `.github/ISSUE_TEMPLATE/` works without changes.
- **Redmine's own concepts on top.** The tracker (bug, feature…), the priority, the category, the target version, the private flag, custom fields, and which fields of the issue form are shown, hidden or required, are set in the same files.
- **The chooser replaces the first step of "New issue".** Users pick a template before the form, as on GitHub, instead of choosing a template inside the form.
- **The repository is the source.** Templates follow the default branch. Projects without a repository keep their templates in the project settings.

## Files

Redmine reads the first of these folders that has at least one file, on the repository's default branch:

1. `.redmine/ISSUE_TEMPLATE/`
2. `.github/ISSUE_TEMPLATE/`

The folders are not merged: `.redmine/` replaces `.github/`, so that a repository can keep different templates for GitHub and for Redmine.

| File | Kind |
| --- | --- |
| `*.md` | Markdown issue template: YAML front matter (`name`, `about`, `title`, `labels`, `assignees`, `type`) and the issue body |
| `*.yml`, `*.yaml` | YAML issue form: `name`, `description`, `body` and the optional `title`, `labels`, `assignees`, `type`, `projects` |
| `config.yml` | Template chooser: `blank_issues_enabled`, `contact_links` |

The chooser lists the templates as GitHub does: alphanumerically by file name, YAML forms before Markdown templates.

### Redmine keys

GitHub ignores the keys it doesn't know in front matter, so the Redmine settings go under one key, `redmine`, in a Markdown template's front matter or at the top level of an issue form.

```yaml
redmine:
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

### GitHub keys in Redmine

| GitHub key | In Redmine |
| --- | --- |
| `name`, `about` / `description` | The chooser's name and description |
| `title` | The subject the form starts with |
| `type` | The tracker of the same name, unless `redmine.tracker` is set |
| `labels` | The first label that is the name of a tracker sets the tracker, unless `redmine.tracker` or `type` sets it. Other labels have no equivalent and are reported as a warning |
| `assignees` | The first login that can be assigned in the project becomes the assignee |
| `projects` | No equivalent; reported as a warning |
| Body of a Markdown template | The description the form starts with |
| `body` of an issue form | The form's fields, shown in place of the description |

### Issue forms

Every element type of GitHub's form schema is supported: `markdown`, `textarea` (`label`, `description`, `placeholder`, `value`, `render`; `required`, `min_length`), `input` (`label`, `description`, `placeholder`, `value`; `required`, `min_length`), `dropdown` (`label`, `description`, `multiple`, `options`, `default`; `required`), `checkboxes` (`label`, `description`, options with `label` and `required`; `required`) and `upload` (`label`, `description`; `required`, `accept`). The files are checked with GitHub's rules (required keys, permitted keys and attributes, unique ids and labels, ids of letters, digits, `-` and `_`, at least one field that is not `markdown`, distinct dropdown options, no reserved `None`, no booleans in options).

When the issue is created, the answers become the description in Markdown, the way GitHub writes the issue body: a `### <label>` heading per field, the answer below it, `_No response_` when it is empty, a fenced code block for a `textarea` with `render`, the chosen options separated by commas for a `dropdown`, `- [X] <label>` or `- [ ] <label>` per option for `checkboxes`. `upload` uses the issue's own files field; its section lists the attached files.

Redmine shows descriptions with its text formatting setting. Templates are Markdown, so the setting should be CommonMark Markdown; the project settings tab warns when it is not.

## Import and sync

The project stores the files it uses (`issue_template_files`) and where they came from (`issue_template_sources`: repository, GitHub, or the project settings; the revision; the time; the errors and warnings of each file). Pages read the stored files; they never read the repository.

- **Redmine's repository.** After Redmine fetches the changesets of the project's main repository, the plugin compares the template folder's files with the stored ones, imports them again when they differ, and records the last revision that changed the folder. Any SCM Redmine supports works, through Redmine's own repository adapters. The project settings tab has a button that imports at once.
- **redmine_github.** [Redmine GitHub](https://github.com/redmine-kit/redmine_github) receives GitHub's push events. When a push to the default branch changes `.redmine/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE/`, it calls `RedmineIssueTemplate::Importer.import(project, files:, revision:, source: 'github')` with the folder's files.
- **Project settings.** A project without templates in its repository edits its files in the project settings. When the repository has templates, they are used, and the settings show them read-only.

A file with errors is listed with its errors in the settings and left out of the chooser; the other files still work.

## Screens

The screens follow Redmine's own screens ([Redmine Design Guide](https://redmine-kit.github.io/design-guide/)).

- **Template chooser** (`/projects/<id>/issues/templates`): "New issue" opens it when the project has templates. A list like Redmine's lists (`table.list`): the template's name (a link to the form), its description and its tracker. "Blank issue" is an action link, shown when `blank_issues_enabled` is not false, or to users who can manage the templates, marked as such. Contact links follow as a second list. Parameters that came with "New issue" (for example a parent issue) are kept.
- **Issue form**: Redmine's own form, with the template's values. An issue form's fields are shown after the issue's attributes, in the form's tabular layout. Hidden fields are left out and required ones are marked as Redmine marks them.
- **Project settings › Issue templates**: where the templates come from, the last import, "Import now", the templates with their errors and warnings, and, without templates in the repository, the files to add, edit and delete.

## Permissions

The project module "Issue templates" turns the plugin on for a project. "Manage issue templates" allows the settings tab, editing and importing. The chooser and the forms need "Add issues", as Redmine's own form does.

## Not covered

- Pull request templates and discussion templates.
- Labels, GitHub Projects and issue types have no Redmine equivalent beyond the tracker; they are reported as warnings.
- Branches other than the default branch.
