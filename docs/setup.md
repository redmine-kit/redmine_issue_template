# Setup

## Requirements

- Redmine 7.0 or later.
- CommonMark Markdown as Redmine's text formatting (Administration › Settings › General). Templates and the answers of YAML forms are Markdown; with Textile the descriptions are not shown as intended.
- For templates in a repository: a project repository that Redmine can read (Git or any other SCM Redmine supports).

## Installation

Put the plugin in `plugins/redmine_issue_template`, run its migrations and restart Redmine. The migrations create the tables `issue_template_files` and `issue_template_sources`.

```sh
bin/rake redmine:plugins:migrate
```

### Gem

Each version tag (`v*`) publishes the plugin as a gem to GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`). Installing from GitHub Packages needs a GitHub token with `read:packages`, even for a public package. Redmine loads plugins only from `plugins/`, so the installed gem is linked there.

```ruby
# Redmine's Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <user>:<token>   # or BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
ln -s "$(bundle info --path redmine_issue_template)" plugins/redmine_issue_template
```

### Without the gem

Clone the repository into `plugins/redmine_issue_template`. The plugin needs no other gems.

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_issue_template
```

## Configuration

Turn on the project module "Issue templates" in the project's settings (or for new projects in Administration › Settings › Projects). Give the roles that maintain the templates the permission "Manage issue templates": it shows the "Issue templates" tab of the project settings, the import button and the file editor. Using the chooser needs only "Add issues".

Then add templates to the repository ([Template format](format.md)) and fetch the repository, or add the files in the project settings ([Import and sync](sync.md)).

## Tests

`bin/test` runs the plugin's tests in Redmine 7.0.3 on PostgreSQL 16 in Docker, then Redmine's tests of the issue form, the project settings and the Git repository with the plugin installed. `bin/test --redmine` runs every Redmine test. The examples of GitHub's documentation are in `test/fixtures/github/` and are tested as they are.

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # on Redmine's master branch
bin/services --down              # stops PostgreSQL
bin/lint                         # RuboCop and Brakeman
bin/screenshots                  # the screenshots of the docs (docs/images/, docs/ja/images/)
```

`bin/screenshots` takes the screenshots in headless Chromium from Redmine's test data and GitHub's examples (`test/screenshots/screens.rb`). Run it after changing a screen.

## To verify

- Templates in Subversion, Mercurial and other SCMs (the tests use Git).
- Large repositories: the import reads the template folder after every fetch; the time it takes there.
