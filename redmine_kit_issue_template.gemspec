# frozen_string_literal: true

require 'yaml'

# The plugin as a gem, published to GitHub Packages (.github/workflows/gem.yml)
# (docs/setup.md, "Installation"): Bundler requires
# boot/redmine_kit_issue_template.rb, which hands the gem's folder to Redmine's
# plugin loader. The gem holds the plugin's run-time files; the module's source
# (frontend/) is not one: its build is in assets/.
Gem::Specification.new do |spec|
  spec.name = 'redmine_kit_issue_template'
  spec.version = File.read(File.join(__dir__, 'lib/redmine_kit/issue_template.rb'))[/VERSION = '([^']+)'/, 1]
  spec.summary = 'Issue templates'
  spec.authors = ['Redmine Kit']
  spec.license = 'GPL-2.0-or-later'
  spec.homepage = 'https://github.com/redmine-kit/redmine_issue_template'
  # The Ruby versions of Redmine 7.0 (its Gemfile: ruby '>= 3.2.0', '< 4.1.0').
  spec.required_ruby_version = ['>= 3.2', '< 4.1']
  spec.files = Dir['{init.rb,LICENSE}', '{app,assets,boot,config,db,help,lib}/**/*']
  # boot/ only: lib/ is the code loader's (Zeitwerk), never required by name.
  spec.require_paths = ['boot']
  spec.metadata['github_repo'] = 'ssh://github.com/redmine-kit/redmine_issue_template'
  # The plugins it requires (config/dependencies.yml): installing the gem installs them.
  YAML.safe_load_file(File.join(__dir__, 'config/dependencies.yml'))['requires'].each do |name, range|
    spec.add_dependency name, range
  end
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['documentation_uri'] = 'https://redmine-kit.github.io/redmine_issue_template/'
end
