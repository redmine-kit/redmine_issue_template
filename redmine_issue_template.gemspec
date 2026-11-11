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
  spec.required_ruby_version = '>= 3.2'
  spec.files = Dir['{init.rb,LICENSE}', '{app,assets,config,db,lib}/**/*']
  # RubyGems needs a require path: lib (the default), as in the other plugins.
  # Bundler may then require lib/redmine_issue_template.rb before Redmine
  # starts; it only defines the module, and init.rb sets the plugin up.
  spec.require_paths = ['lib']
  spec.metadata['github_repo'] = 'ssh://github.com/redmine-kit/redmine_issue_template'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['documentation_uri'] = 'https://redmine-kit.github.io/redmine_issue_template/'
end
