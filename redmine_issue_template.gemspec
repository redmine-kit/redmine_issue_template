# frozen_string_literal: true

# The plugin as a gem, published to GitHub Packages (.github/workflows/gem.yml).
# The gem holds the plugin's run-time files, so that the installed gem can be
# linked into Redmine's plugins/ (docs/setup.md#installation).
Gem::Specification.new do |spec|
  spec.name = 'redmine_issue_template'
  spec.version = File.read(File.join(__dir__, 'lib/redmine_issue_template.rb'))[/VERSION = '([^']+)'/, 1]
  spec.summary = "Issue templates for Redmine, synced from the project's repository"
  spec.authors = ['Redmine Kit']
  spec.license = 'GPL-2.0-or-later'
  spec.homepage = 'https://github.com/redmine-kit/redmine_issue_template'
  spec.required_ruby_version = '>= 4.0'
  spec.files = Dir['{init.rb,LICENSE}', '{app,assets,config,db,lib}/**/*']
  spec.require_paths = []
  spec.metadata['github_repo'] = 'ssh://github.com/redmine-kit/redmine_issue_template'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
