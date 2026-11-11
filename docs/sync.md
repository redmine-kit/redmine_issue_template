# Import and sync

A project's templates are stored in Redmine. The pages read the stored files and never the repository, so a slow or unreachable repository doesn't slow down "New issue". The stored files come from one of three places, and the "Issue templates" tab of the project settings shows which one.

| Source | How the files arrive | Where they are edited |
| --- | --- | --- |
| Repository | Redmine's main repository of the project, after each fetch, or with "Import" | In the repository |
| GitHub | [Redmine GitHub](https://github.com/redmine-kit/redmine_github), on a push to the default branch | On GitHub |
| Project settings | The file editor of the tab | In Redmine |

## The project's repository

When Redmine fetches the changesets of the project's main repository (when someone opens the repository and "Fetch commits automatically" is on, with `Repository.fetch_changesets` from cron, or through Redmine's repository web service), the plugin reads the template folder on the default branch and compares it with the stored files. When the files differ, it imports them and records the last revision that changed the folder. Reading uses Redmine's own repository adapters, so it works with every SCM Redmine supports.

"Import" in the project settings reads the folder at once, without waiting for a fetch.

When the repository no longer has a template folder, the templates that came from it are removed. Templates edited in the project settings are kept.

## Redmine GitHub

[Redmine GitHub](https://github.com/redmine-kit/redmine_github) connects GitHub repositories through a GitHub App. When GitHub reports a push to the default branch that changes `.redmine/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE/`, Redmine GitHub reads the folder (the first one that has files) and hands the files to this plugin:

```ruby
RedmineIssueTemplate::Importer.import(
  project,
  files: { 'bug_report.yml' => '...', 'config.yml' => '...' },  # file names in the folder => content
  revision: 'c0ffee…',                                          # the commit
  source: 'github',
  folder: '.github/ISSUE_TEMPLATE'
)
```

The call replaces the project's files and returns the import's record with the errors and warnings. Templates that came from GitHub are not replaced by a fetch of a Redmine repository; "Import" replaces them on purpose.

## The project settings

A project whose repository has no templates (or that has no repository) adds, edits and deletes the files in the tab. The files are the same as in a repository, edited as text. Saving checks the file as an import does, and a file with errors is not saved. "Preview" shows the template's row in the chooser and the New issue form it makes, without saving. Files that came from a repository are shown read-only, with the same preview. When the repository gets templates, they replace the edited ones at the next fetch.

## Errors and warnings

Each import checks every file ([Checks](format.md#checks)); the tab marks the files with errors, and each file's page lists its errors and warnings. An error leaves the file out of the chooser; a warning, such as a label without a Redmine equivalent or a tracker the project doesn't have, leaves the template in use.
