# Issue templates

Issue templates fill in the form of **New issue**: the tracker, the subject, the description and the fields a template sets. When a project has templates, **New issue** opens the template chooser first. A YAML form shows fields of its own and writes the answers into the description when the issue is created.

The templates are files in `.redmine/ISSUE_TEMPLATE/` of the project's repository (`.github/ISSUE_TEMPLATE/` is not read), or files edited in the project's settings. Issue templates is a module: turn on **Issue templates** in the project's **Settings** › **Modules**.

## Permissions

| Permission | Allows |
| --- | --- |
| **Add issues** (Redmine's) | using the template chooser and the templates |
| **Manage issue templates** | the project settings' **Issue templates** tab: importing, adding, changing and deleting the files, the chooser's settings and **Sharing** (members only); creating an issue without a template where blank issues are not allowed |

Give them to roles in **Administration** › **Roles and permissions**.

## The template chooser

**New issue** lists the templates the project can use, with their **Name**, **Description** and **Tracker**. Click a template's name to open the issue form with it. **Blank issue** opens the form without a template; it is there when `config.yml` allows blank issues. **Other contacts** lists the links of `config.yml` (for example a forum or a security contact), which open in a new tab.

A template with errors is not in the chooser. Where blank issues are not allowed, an issue can't be created without a template ("Choose a template to create an issue."), except by users with **Manage issue templates**.

## The issue form

The form shows the chosen template's values: the tracker, the subject and the description it starts with, and the values of the fields it sets, which can't be changed in the form. A template can also hide fields of the form or make them required.

A YAML form shows its description and its fields at the top of the form, where the description would be. When the issue is created, the answers become the issue's description, each under the field's label; an upload field's files are attached to the issue.

## Where the templates come from

The project's **Settings** › **Issue templates** tab shows where the templates come from (**Source**):

- **Repository**: Redmine imports the files of `.redmine/ISSUE_TEMPLATE/` on the default branch each time it fetches new changesets of the project's main repository. **Import** reads the folder at once; it replaces the templates edited in the project settings.
- **GitHub**: with Redmine Kit GitHub, a push to the default branch imports the folder.
- **Project settings**: a project without templates in a repository adds, changes and deletes the files in the tab.

Redmine shows only the stored files; it never reads the repository when **New issue** is opened.

## The Issue templates tab

The tab lists the files with their **File**, **Name** and **Tracker**, and marks the files with errors. Click a file to see its content, its errors and warnings, and **Preview**: the template's row in the chooser and the issue form it makes. An error leaves the template out of the chooser; a warning (such as a tracker the project doesn't have) leaves it in use.

When the files are edited in Redmine, **New template** adds a file (`.md`, `.yml`, `.yaml` or `config.yml`), and each file has **Edit** and **Delete**. Saving checks the file, and a file with errors is not saved. **Preview** shows the text as typed, without saving.

**Template chooser** holds the settings of `config.yml`: **Allow blank issues** and **Other contacts** (name, URL and description of each link). They are saved from the tab when the files are edited in Redmine, which rewrites `config.yml`; otherwise they are shown read-only and changed in `config.yml` where the templates are kept.

**Sharing** shares the project's templates with other projects, with the values of a version's sharing (**Not shared**, **With subprojects**, **With project hierarchy**, **With project tree**, **With all projects**). A project with no templates of its own uses those of the nearest project that shares them with it; **Shared from** names that project.

A copy of the project (**Copy**) can take the templates with it: the item **Issue templates** of the copy page. The copy's templates are edited in its settings.

## Template files

- **Markdown templates** (`.md`): front matter with `name` and `about` (required) and Redmine's keys, then the description the form starts with.
- **YAML forms** (`.yml`, `.yaml`): `name`, `description` and `body`, the fields of the form (`markdown`, `input`, `textarea`, `dropdown`, `checkboxes`, `upload`). A field with `link` sets an issue field.
- **Redmine's keys**: `tracker`, `priority`, `category`, `fixed_version`, `is_private`, `custom_fields`, and `fields` (`shown`, `hidden` or `required` for each field).
- **`config.yml`**: `blank_issues_enabled` and `contact_links`, the chooser's settings.

Templates and answers are Markdown: use CommonMark Markdown as the text formatting (**Administration** › **Settings** › **General**); the tab warns otherwise. The full format: [Template format](https://redmine-kit.github.io/redmine_issue_template/format).
