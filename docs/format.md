# Template format

The files are GitHub's issue templates. A folder that works on GitHub works here unchanged, and Redmine's settings go under one extra key, `redmine`, which GitHub ignores. The format follows GitHub's documentation, checked on 2026-11-10: "Configuring issue templates for your repository", "Syntax for issue forms", "Syntax for GitHub's form schema" and "Common validation errors when creating issue forms".

## Folder

Redmine reads the first of these folders that has template files, on the default branch of the project's repository:

1. `.redmine/ISSUE_TEMPLATE/`
2. `.github/ISSUE_TEMPLATE/`

The folders are not merged. A repository that wants other templates in Redmine than on GitHub puts them in `.redmine/`.

The chooser lists the templates as GitHub does: issue forms (`.yml`, `.yaml`) first, then Markdown templates (`.md`), each sorted by file name. Prefix the file names with numbers to set the order (`1-bug.yml`, `2-feature.md`). The file name without its extension is the template's id in URLs (`?issue_template=1-bug`).

## Markdown templates

A Markdown template has YAML front matter and the description the form starts with. `name` and `about` are required.

```markdown
---
name: 🐞 Bug
about: File a bug/issue
title: '[BUG] <title>'
labels: Bug, Needs Triage
assignees: ''
---

### Current Behavior:
<!-- A concise description of what you're experiencing. -->

### Steps To Reproduce:
```

## Issue forms

An issue form is YAML with `name`, `description` and `body`, and optionally `title`, `labels`, `assignees`, `type` and `projects`. The form shows its fields in place of the description, and the answers become the description when the issue is created. This is GitHub's own example, which Redmine reads as it is:

```yaml
name: Bug Report
description: File a bug report.
title: "[Bug]: "
labels: ["bug", "triage"]
type: bug
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      value: "A bug happened!"
    validations:
      required: true
  - type: dropdown
    id: version
    attributes:
      label: Version
      options:
        - 1.0.2 (Default)
        - 1.0.3 (Edge)
      default: 0
    validations:
      required: true
  - type: checkboxes
    id: terms
    attributes:
      label: Code of Conduct
      options:
        - label: I agree to follow this project's Code of Conduct
          required: true
```

### Fields

Every element type of GitHub's form schema works. Each one has `attributes` and, except `markdown`, an optional `id` (letters, digits, `-`, `_`) and `validations`.

| Type | Attributes | Validations | In the form |
| --- | --- | --- | --- |
| `markdown` | `value` | none | Text, not submitted |
| `textarea` | `label`, `description`, `placeholder`, `value`, `render` | `required`, `min_length` | A text area; with `render`, the answer becomes a code block in that language |
| `input` | `label`, `description`, `placeholder`, `value` | `required`, `min_length` | A one-line text field |
| `dropdown` | `label`, `description`, `multiple`, `options`, `default` | `required` | A select box; `default` is the index of the preselected option |
| `checkboxes` | `label`, `description`, `options` (each with `label` and `required`) | `required` | A checkbox per option |
| `upload` | `label`, `description` | `required`, `accept` | Redmine's Files field of the issue; the section lists the attached files |

GitHub checks some validations only in public repositories; Redmine always checks them.

### The description

The answers are written as GitHub writes the issue body: a `### <label>` heading for each field, then the answer. An empty answer is `_No response_`. A dropdown's chosen options are separated by commas, and each checkbox option becomes `- [X] <label>` or `- [ ] <label>`.

```markdown
### What happened?

It crashed.

### Version

1.0.2 (Default)

### Code of Conduct

- [X] I agree to follow this project's Code of Conduct
```

### Checks

The files are checked with GitHub's rules: the required keys, the permitted keys and attributes, unique ids and labels, labels that stay different when made into parameters, at least one field that is not `markdown`, distinct dropdown options without the reserved word `None` and without values YAML reads as booleans, keys that YAML reads as booleans (`yes`, `no`, `on`, `off`…), and a `name` longer than 3 characters. A file that breaks a rule is listed with its errors in the project settings and left out of the chooser; the other files still work.

## config.yml

`config.yml` sets the chooser. Without it, blank issues are allowed.

```yaml
blank_issues_enabled: false
contact_links:
  - name: GitHub Community Support
    url: https://github.com/orgs/community/discussions
    about: Please ask and answer questions here.
```

- `blank_issues_enabled: false` hides "Blank issue" from the chooser. Users with "Manage issue templates" still see it, marked "maintainers only", as GitHub shows it to users with write access.
- `contact_links` are listed after the templates, as links to other places to ask.

## Redmine keys

The `redmine` key is in a Markdown template's front matter, or at the top level of an issue form.

```yaml
redmine:
  tracker: Bug
  priority: High
  category: UI
  fixed_version: "2.0"
  is_private: false
  custom_fields:
    Severity: Major
  fields:
    assigned_to: hidden
    estimated_hours: hidden
    due_date: required
    Severity: required
```

| Key | Value |
| --- | --- |
| `tracker` | The tracker, by name or id |
| `priority` | The priority, by name or id |
| `category` | A category of the project, by name or id |
| `fixed_version` | An open version of the project, by name or id |
| `is_private` | `true` or `false` |
| `custom_fields` | Custom field names (or ids) and their values |
| `fields` | The visibility of the form's fields |

Names are compared without case. A name that the project doesn't have is reported as a warning in the project settings, and the field keeps Redmine's default.

### Fields of the form

`fields` sets a field to `shown` (the default), `hidden` or `required`. A hidden field is left out of the form and keeps the value the template sets; a required field is marked and checked as Redmine marks and checks the fields its workflow requires. The names are `assigned_to`, `category`, `fixed_version`, `parent_issue`, `start_date`, `due_date`, `estimated_hours`, `done_ratio`, `description` (Markdown templates; an issue form always replaces it), `priority`, `is_private`, `watchers`, and custom fields by name or id.

The tracker, the subject and the project are always shown, as Redmine requires them. Redmine's own rules still apply: a field the tracker disables is not shown even when the template shows it, and a field the workflow makes read-only stays read-only.

## GitHub's keys in Redmine

Some of GitHub's keys have no Redmine equivalent. They don't stop a template from working; the project settings list them as warnings.

| GitHub key | In Redmine |
| --- | --- |
| `name` | The template's name in the chooser |
| `about`, `description` | The template's description in the chooser |
| `title` | The subject the form starts with |
| `type` | The tracker of the same name, unless `redmine.tracker` is set |
| `labels` | The first label that is a tracker's name sets the tracker, unless `redmine.tracker` or `type` does. Other labels are ignored, with a warning |
| `assignees` | The first login that can be assigned in the project becomes the assignee; logins that can't be assigned are reported |
| `projects` | Ignored, with a warning |
| Markdown template body | The description the form starts with |
| Issue form `body` | The form's fields; the answers become the description |
