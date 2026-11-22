# Setup

## Requirements

- Redmine 7.0 or later.
- CommonMark Markdown as Redmine's text formatting (Administration › Settings › General). Templates and the answers of YAML forms are Markdown; with Textile the descriptions are not shown as intended.
- For templates in a repository: a project repository that Redmine can read (Git or any other SCM Redmine supports).

## Installation

The plugin is installed as a gem (first choice) or in `plugins/`. Its migrations create the tables `redmine_kit_issue_template_files` and `redmine_kit_issue_template_sources`. Restart Redmine afterwards.

### Gem

Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`). Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. Add the gem to Redmine's `Gemfile.local`, then install and migrate from Redmine's folder:

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
bin/rails redmine:plugins:migrate RAILS_ENV=production
```

Bundler requires `boot/redmine_kit_issue_template.rb`, which hands the gem's folder to Redmine's plugin loader: Redmine runs the gem's `init.rb`, serves its assets, strings, views and migrations, adds its `lib/` and `app/` to Rails' code loader and draws its routes, as for a plugin in `plugins/`. A folder of the same id in `plugins/` wins over the gem.

### In plugins/

Clone the repository into `plugins/redmine_kit_issue_template` and run its migrations. The plugin needs no other gems.

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_kit_issue_template
bin/rails redmine:plugins:migrate RAILS_ENV=production
```

## Configuration

Turn on the project module "Issue templates" in the project's settings (or for new projects in Administration › Settings › Projects). Give the roles that maintain the templates the permission "Manage issue templates": it shows the "Issue templates" tab of the project settings, the import button and the file editor. Using the chooser needs only "Add issues".

Then add templates to the repository ([Template format](format.md)) and fetch the repository, or add the files in the project settings ([Import and sync](sync.md)).

## Redmine Kit's new UI

With [Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) installed, the plugin works in its new UI too,
through its extension API (`kit_ui` in `init.rb`; nothing to set up):

- **New issue** shows the template chooser as a step of the new UI's form. The chosen template is at the form's top
  (‹ back to the chooser before its name, then its description), and a form's fields come after the subject, where the
  description would be: a text area is the compact Markdown editor (with `render`, a plain text area whose note says
  the answer is recorded as a code block), a dropdown with `multiple` a list of several choices, and a field with `link`
  notes the issue's field it sets. The values the template sets are shown at their fields, read-only
  (Read-only (set by the template)), and a form folds the issue's other fields under Other fields, with a summary (the
  required ones stay out). Create waits for the form's required answers and names the first one; a click on it shows
  each field's message. What was typed into a template stays while the form is open: going back marks it Draft in the
  chooser, and choosing it again continues it. The page's sidebar shows where the templates come from (the template's
  file), the fields it hides and, for users who manage templates, a link to Settings › Issue templates. The rules are
  the same as in Redmine's form (hidden, preset, linked and required fields; the answers in the description; blank
  issues as `config.yml` says), decided by the plugin on the server.
- **Upload fields** are the new UI's own file field: the new UI uploads the files with Redmine's limits (size,
  extensions, the field's `accept`) and sends them with Redmine's own uploads, and the form names them by attachment id;
  the server takes only files of that request that the user uploaded.
- **Project settings › Issue templates** has two panes: the files with their state (errors, warnings), then
  Template chooser (`config.yml`); and the chosen file with Edit and Delete, its messages, Preview (the chooser's row and
  the new issue's form with it, as users see them), Content, and for `config.yml` Settings (blank issues and contact links).
  Source says where the files come from (the repository's folder, revision and date, or Project settings when they are
  edited there); a file's messages are headed Error or Warning; Settings explains Allow blank issues and notes that saving
  rewrites `config.yml`.
  The header has Help, Import (with a repository; its tooltip says it reads the folder now, and it asks first when it would replace files edited in Redmine) and New template (when the files are edited in Redmine). A new file and Edit open the file's form in a
  drawer, with Preview of the text as typed; the form's URL (`/projects/<id>/issue_templates/new`,
  `…/<file>/edit`) shows the same form as a page, beside the settings' tabs, with Format help.

The new UI's module is `assets/javascripts/kit/issue_template.js`, built from `frontend/` (React and TypeScript):
`bin/setup` builds the app's packages it is built against (`@redmine-kit/ui`, `@redmine-kit/plugin`) in the ui
checkout next to this repository and installs the frontend's packages; then `cd frontend && npm run check` type-checks
it, runs its tests (`npm test`: Vitest and Testing Library, with `@redmine-kit/plugin/testing`), builds it and runs
`kit-check-ui`. Commit the built file with the source.

## MCP

With [redmine_kit_mcp](https://github.com/redmine-kit/redmine_kit_mcp) installed, AI clients use the templates through
MCP, with the user's permissions and the token's scopes:

| Tool | What | Writes | Permission (scope) |
| --- | --- | --- | --- |
| `issue_template.list_templates` | The templates the user may use in a project (key, name, description, tracker; a form's fields with their options and the values the template sets) and whether a blank issue is allowed | | `add_issues` |
| `issue_template.create_issue` | A new issue from a template, as Redmine's form makes it: the template's values for what isn't given, the fields it sets and hides out of reach, a form's `answers` (by field ref; dropdowns and checkboxes by option value) composed into the description and checked | yes | `add_issues` |

Where `blank_issues_enabled` is false, MCP's own `create_issue` is refused with Choose a template to create an issue.,
as in the browser, unless the user manages the templates and the token has the scope `manage_issue_templates`
(both tools offer it, as Redmine asks a token's scopes for every permission). Upload fields can't be answered through MCP.

## Tests

`bin/test` runs the plugin's tests in Redmine 7.0.3 on PostgreSQL 16 in a container ([Apple container](https://github.com/apple/container) when it is installed and running, else Docker; `CONTAINER_CLI=container` or `CONTAINER_CLI=docker` chooses), then Redmine's tests of the issue form, the project settings and the Git repository with the plugin installed, then the tests of the MCP tools with redmine_kit_mcp and redmine_kit_ui (the checkouts next to this one, or `REDMINE_KIT_MCP_DIR` and `REDMINE_KIT_UI`; `REDMINE_KIT_MCP=1 bin/test test/integration/mcp_tools_test.rb` runs them alone). `bin/test --redmine` runs every Redmine test. The examples of GitHub's documentation are in `test/fixtures/github/` and are tested as they are.

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # on Redmine's master branch
COVERAGE=1 bin/test              # also the plugin's coverage (coverage/coverage.xml)
bin/test-gem                     # the plugin installed as a gem, then from plugins/
bin/services --down              # stops PostgreSQL (and Chromium)
bin/lint                         # RuboCop and Brakeman (in the same container tool)
bin/screenshots                  # the screenshots of the docs (docs/images/, docs/ja/images/)
```

`COVERAGE=1 bin/test` also measures the coverage of the plugin's files by its tests ([SimpleCov](https://github.com/simplecov-ruby/simplecov), in one worker, so it takes longer) and writes it as Cobertura XML to `coverage/coverage.xml`. CI runs it on Redmine 7.0.3 and uploads the file to [Codecov](https://app.codecov.io/gh/redmine-kit/redmine_issue_template) with GitHub's OIDC token, without a Codecov token (`.github/workflows/ci.yml`, `codecov.yml`).

`bin/screenshots` (in Apple container or Docker, as `bin/test`) takes the screenshots in headless Chromium from Redmine's test data and GitHub's examples (`test/screenshots/screens.rb`). Run it after changing a screen.

## To verify

- Templates in Subversion, Mercurial and other SCMs (the tests use Git).
- Large repositories: the import reads the template folder after every fetch that adds changesets; the time it takes there.
