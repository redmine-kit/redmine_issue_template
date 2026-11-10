# AGENTS.md

Guidelines for people and coding agents working in this repository. See [README.md](README.md) for an overview and [docs/](docs/README.md) for the design. The organization's rules for Redmine screens and translations are in `../AGENTS.md` (not in this repository).

## What this project does

Redmine Issue Template (`redmine_issue_template`) is a Redmine plugin for issue templates: "New issue" opens a template chooser, and Markdown templates and YAML forms fill in and shape the issue form. The templates are read from `.redmine/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE/` of the project's repository, from GitHub through [redmine_github](https://github.com/redmine-kit/redmine_github), or edited in the project settings ([design.md](docs/design.md)). It is in early development.

## Rules

- **The template format.** The plugin reads Markdown templates, YAML issue forms and `config.yml` from the template folder and checks them with its own rules. Redmine's keys are top-level keys whose names no other key uses. Document every key and what it does in the issue form in [format.md](docs/format.md).
- **The plugin in its own terms.** The documentation, the screens and the messages describe what the plugin does. They never describe GitHub's behavior or compare the plugin with GitHub.
- **Redmine's own screens.** The chooser, the settings tab and the file pages follow Redmine's core screens (enumerations, project settings tabs, issue categories); the issue form stays Redmine's form. Plugin CSS only with a reason.
- **Redmine's extension points only:** do not edit Redmine's own files. The plugin prepends modules to `Issue`, `IssuesController`, `ProjectsHelper` and the `Repository` classes; keep them small.
- **Pages never read the repository.** Imports store the files; pages read the stored files.
- **Tests:** added code has tests, run with Redmine's own mechanism (`bin/test` runs them in Docker with PostgreSQL; [setup.md](docs/setup.md#tests)). The example templates in `test/fixtures/github/` are tested as they are.
- **No secrets in the repository.**

## Documentation

- **Two languages.** English is the source (`README.md`, `docs/`); the Japanese translation is `README.ja.md` and `docs/ja/`, with the same file names. Change both together.
- **Layout.** The READMEs stay short. The details go in `docs/`, published at https://redmine-kit.github.io/redmine_issue_template/ with [redmine-kit/docs-skeleton](https://github.com/redmine-kit/docs-skeleton).
- **Anchors in Japanese.** Put `<a id="..."></a>` with the English heading's anchor before each Japanese heading.
- **Facts.** State only what has been checked, with the date and the source. Mark what has not been checked yet.
- **Japanese wording.** Plain, precise Japanese; UI terms exactly as Redmine's `config/locales/ja.yml` has them. Do not use "版" for a version, write "通知" rather than "知らせ", "確認" rather than "確かめ", "インストール" rather than "入れ方", "コピー" rather than "写す", "バージョンアップ" for upgrading, and "例外を発生させる" for raising an exception.

## Commits

- English, imperative mood, 72 characters or fewer in the first line, no trailing period.
- One purpose per commit.
- Do not rewrite pushed history.
