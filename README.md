# Redmine Issue Template

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/redmine_issue_template/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/redmine_issue_template/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/redmine_issue_template?label=Coverage)](https://codecov.io/gh/redmine-kit/redmine_issue_template)
[![License](https://img.shields.io/github/license/redmine-kit/redmine_issue_template?label=License)](LICENSE)

Redmine Issue Template (`redmine_issue_template`) is a Redmine plugin that brings GitHub's issue templates to Redmine. "New issue" opens a template chooser, and the chosen template fills in the issue form. The templates are files in the project's repository, in the same format as GitHub's, so a repository that already has `.github/ISSUE_TEMPLATE/` works as it is.

[日本語](README.ja.md)

> **Status:** early development.

- Markdown issue templates, YAML issue forms and `config.yml`, as GitHub defines them, with Redmine's tracker, priority, category, target version and custom fields under one `redmine` key.
- Each template can hide fields of the issue form or make them required.
- Redmine imports the templates when the repository changes; projects without a repository edit them in the project settings. [Redmine GitHub](https://github.com/redmine-kit/redmine_github) can import them from GitHub.

## Documentation

- Website: https://redmine-kit.github.io/redmine_issue_template/ (日本語: https://redmine-kit.github.io/redmine_issue_template/ja/)
- Markdown: [docs/README.md](docs/README.md) (日本語: [docs/ja/README.md](docs/ja/README.md))

## Sponsors

<a href="https://www.keyselect.co.jp/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/keyselect-logo-dark.svg">
    <img alt="KEY SELECT" src=".github/assets/keyselect-logo.svg" width="136" height="29">
  </picture>
</a>

## License

Redmine Issue Template is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](LICENSE). An unofficial Redmine plugin.
