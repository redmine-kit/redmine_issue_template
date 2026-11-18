# Setup

## Requirements

- Redmine 7.0 or later.
- CommonMark Markdown as Redmine's text formatting (Administration › Settings › General). Templates and the answers of YAML forms are Markdown; with Textile the descriptions are not shown as intended.
- For templates in a repository: a project repository that Redmine can read (Git or any other SCM Redmine supports).

## Installation

Put the plugin in `plugins/redmine_kit_issue_template`, run its migrations and restart Redmine. The migrations create the tables `issue_template_files` and `issue_template_sources`.

```sh
bin/rake redmine:plugins:migrate
```

### Gem

Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`). Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. Redmine loads plugins only from `plugins/`, so the installed gem is linked there.

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_kit_issue_template)" plugins/redmine_kit_issue_template
```

### Without the gem

Clone the repository into `plugins/redmine_kit_issue_template`. The plugin needs no other gems.

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_kit_issue_template
```

## Configuration

Turn on the project module "Issue templates" in the project's settings (or for new projects in Administration › Settings › Projects). Give the roles that maintain the templates the permission "Manage issue templates": it shows the "Issue templates" tab of the project settings, the import button and the file editor. Using the chooser needs only "Add issues".

Then add templates to the repository ([Template format](format.md)) and fetch the repository, or add the files in the project settings ([Import and sync](sync.md)).

## Redmine Kit's new UI

With [Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) installed, the plugin works in its new UI too,
through its extension API (`kit_ui` in `init.rb`; nothing to set up):

- **New issue** shows the template chooser as a step of the new UI's form. The chosen template is at the form's top
  (its name with 変更, its description and the values it sets), and a form's fields come after the subject, where the
  description would be. The rules are the same as in Redmine's form (hidden, preset, linked and required fields; the
  answers in the description; blank issues as `config.yml` says), decided by the plugin on the server.
- **Upload fields** are the new UI's own file field: the new UI uploads the files with Redmine's limits (size,
  extensions, the field's `accept`) and sends them with Redmine's own uploads, and the form names them by attachment id;
  the server takes only files of that request that the user uploaded.
- **Project settings › Issue templates** has two panes: the files with their state (errors, warnings), then
  テンプレートの選択画面 (`config.yml`); and the chosen file with 編集 and 削除, its messages, プレビュー (the chooser's row and
  the new issue's form with it, as users see them), 内容, and for `config.yml` 設定 (blank issues and contact links).
  The header has ヘルプ, インポート (with a repository) and 新しいテンプレート. A new file and 編集 open the file's form in a
  drawer, with プレビュー of the text as typed; the form's URL (`/projects/<id>/issue_templates/new`,
  `…/<file>/edit`) shows the same form as a page, beside the settings' tabs, with 形式のヘルプ.

The new UI's module is `assets/javascripts/kit/issue_template.js`, built from `frontend/` (React and TypeScript):
`bin/setup` builds the app's packages it is built against (`@redmine-kit/ui`, `@redmine-kit/plugin`) in the ui-mock
checkout next to this repository and installs the frontend's packages; then `cd frontend && npm run check` type-checks
it, builds it and runs `kit-check-ui`. Commit the built file with the source.

## Tests

`bin/test` runs the plugin's tests in Redmine 7.0.3 on PostgreSQL 16 in a container ([Apple container](https://github.com/apple/container) when it is installed and running, else Docker; `CONTAINER_CLI=container` or `CONTAINER_CLI=docker` chooses), then Redmine's tests of the issue form, the project settings and the Git repository with the plugin installed. `bin/test --redmine` runs every Redmine test. The examples of GitHub's documentation are in `test/fixtures/github/` and are tested as they are.

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # on Redmine's master branch
COVERAGE=1 bin/test              # also the plugin's coverage (coverage/coverage.xml)
bin/services --down              # stops PostgreSQL
bin/lint                         # RuboCop and Brakeman (in the same container tool)
bin/screenshots                  # the screenshots of the docs (docs/images/, docs/ja/images/)
```

`COVERAGE=1 bin/test` also measures the coverage of the plugin's files by its tests ([SimpleCov](https://github.com/simplecov-ruby/simplecov), in one worker, so it takes longer) and writes it as Cobertura XML to `coverage/coverage.xml`. CI runs it on Redmine 7.0.3 and uploads the file to [Codecov](https://app.codecov.io/gh/redmine-kit/redmine_issue_template) with GitHub's OIDC token, without a Codecov token (`.github/workflows/ci.yml`, `codecov.yml`).

`bin/screenshots` (Docker only for now) takes the screenshots in headless Chromium from Redmine's test data and GitHub's examples (`test/screenshots/screens.rb`). Run it after changing a screen.

## To verify

- Templates in Subversion, Mercurial and other SCMs (the tests use Git).
- Large repositories: the import reads the template folder after every fetch; the time it takes there.
