# AGENTS.md

Guidelines for people and coding agents working in this repository. They add to the organization's rules in `../AGENTS.md` and its checklist `../CHECKLIST.md` (next to this repository, not in it), which cover Redmine screens, wording, plugin implementation, security and tests. See [README.md](README.md) for an overview and [docs/](docs/README.md) for the design.

## What this project does

Redmine Issue Template (`redmine_issue_template`) is a Redmine plugin for issue templates. "New issue" opens a template chooser; Markdown templates and YAML forms fill in and shape the issue form. The templates come from `.redmine/ISSUE_TEMPLATE/` or `.github/ISSUE_TEMPLATE/` of the project's repository, from GitHub through [redmine_github](https://github.com/redmine-kit/redmine_github), or are edited in the project settings ([design.md](docs/design.md)). It is in early development.

## Where things are

| Path | What |
| --- | --- |
| `lib/redmine_issue_template/parser.rb`, `issue_form.rb`, `issue_form_options.rb`, `markdown_template.rb`, `chooser_config.rb`, `redmine_options.rb`, `yaml_nodes.rb` | Reading template files and checking them; `Message` (errors and warnings in Redmine's sentences) |
| `lib/redmine_issue_template/template_set.rb` | A project's parsed templates, cached per process by a database key |
| `lib/redmine_issue_template/importer.rb`, `repository_source.rb`, `repository_patch.rb` | Importing and storing files (the entry point for redmine_github) |
| `lib/redmine_issue_template/issue_patch.rb`, `redmine_rules.rb`, `linked_field.rb`, `body_composer.rb` | What a template does to a new issue: hidden, preset, linked and required fields, the description from the answers |
| `lib/redmine_issue_template/issues_controller_patch.rb`, `issue_template_params.rb` | The chooser redirect, the request's parameters, refusing issues without a template; `IssueTemplateDefaults` (the template's values) |
| `app/controllers/issue_templates_controller.rb`, `app/views/issue_templates/` | The chooser, the settings tab, the file pages, the form box above Redmine's form |
| `app/helpers/issue_templates_helper.rb` | The one Markdown helper |
| `assets/stylesheets/issue_template.css` | The plugin's CSS, each rule with its reason |
| `test/` | Unit and functional tests, `test/screenshots/` for the docs' images, `test/fixtures/github/` example templates |

## Rules

### The template format

- **Documented in [format.md](docs/format.md).** Every key, every element type and attribute, every check and what it does to the issue form is described there, with valid examples.
- **Redmine's keys** are top-level keys whose names no other key uses (`tracker`, `priority`, `category`, `fixed_version`, `is_private`, `custom_fields`, `fields`), and `link` on a YAML form's field (a field with `link` has no `type`). They belong in `.redmine/ISSUE_TEMPLATE/` or the project settings; the files of `.github/ISSUE_TEMPLATE/` keep to GitHub's format.
- **The plugin in its own terms.** The documentation, the screens and the messages describe what the plugin does. They never describe GitHub's behavior or compare the plugin with GitHub.
- **Checks** report errors and warnings as `Message`s in Redmine's validation sentences (`activerecord.errors.messages.*` or `issue_template_error_*`). A file with errors is left out of the chooser; the others still work.

### What a template may do to an issue

- **Within Redmine's rules for the user.** A template hides, presets, links or requires a field only when Redmine lets the user set that field (`Issue#issue_template_settable?`, which asks Redmine's own `safe_attribute_names` and `editable_custom_field_values`). Redmine's validations still run on every field, including the ones the form leaves out.
- **One place.** The template's effect on a new issue (hidden, preset, linked and required fields, and the fields shown again because Redmine requires them) is decided in one place and read by the controller, the issue patch and the views. When adding a rule, add it there; never compute it again elsewhere.
- **The project** can't change while a template applies, and preset values can't be changed by the request.
- **Blank issues** follow `blank_issues_enabled` in `config.yml`, for issues created in the browser; the REST API and email are left to Redmine.

### Screens

- **Redmine's own screens.** The chooser, the settings tab and the file pages follow Redmine's core screens (enumerations, project settings tabs, issue categories); the issue form stays Redmine's form, with a box above it for a YAML form's fields.
- **No JavaScript of the plugin's own.** The box's fields join Redmine's form with the `form` attribute; the tracker field uses Redmine's `updateIssueFrom`.
- **Text from templates** (descriptions, labels, options, contact links) is rendered through `issue_template_markdown` only, which uses Redmine's CommonMark formatter and turns images from other sites into links.

### Data

- **Pages never read the repository.** Imports store the files; pages read the stored files.
- **Files** are stored in UTF-8, with names that `IssueTemplateFile::PATH` accepts and at most `Parser::MAX_LENGTH` characters.

### Tests

- **Commands.** `bin/test` runs the plugin's tests and Redmine's tests of the issue form in Docker with PostgreSQL ([setup.md](docs/setup.md#tests)); `bin/lint` runs RuboCop; `bin/screenshots` makes the docs' images. Run all three before pushing.
- The example templates in `test/fixtures/github/` are tested as they are.
- A change to what a template does to an issue has a functional test that creates the issue and checks the saved values.

## Documentation

- **Two languages.** English is the source (`README.md`, `docs/`); the Japanese translation is `README.ja.md` and `docs/ja/`, with the same file names. Change both together.
- **Layout.** The READMEs stay short. The details go in `docs/`, published at <https://redmine-kit.github.io/redmine_issue_template/> with [redmine-kit/docs-skeleton](https://github.com/redmine-kit/docs-skeleton).
- **Anchors in Japanese.** Put `<a id="..."></a>` with the English heading's anchor before each Japanese heading.
- **Facts.** State only what has been checked, with the date and the source. Mark what has not been checked yet.
- **Wording.** The organization's rules for Japanese apply (`../AGENTS.md`), with UI terms exactly as Redmine's `config/locales/ja.yml` has them.

## Commits

- English, imperative mood, 72 characters or fewer in the first line, no trailing period.
- One purpose per commit.
- Do not rewrite pushed history.
- No secrets in the repository.
