# frozen_string_literal: true

module RedmineIssueTemplate
  # Reads the template folder from the project's main repository, through
  # Redmine's own repository adapters, on the default branch.
  module RepositorySource
    module_function

    # Imports the folder when it changed since the last import (or always
    # with force). Templates kept by redmine_github are left alone unless
    # forced. Returns the IssueTemplateSource, or nil when nothing was done.
    def sync(project, force: false)
      repository = project.repository
      return nil unless repository && project.module_enabled?(:issue_templates)

      current = IssueTemplateSource.for(project)
      return nil if current.kind == 'github' && !force

      folder, files = read(repository)
      return clear(project, current) if folder.nil?
      return nil if !force && current.kind == 'repository' && current.digest == Importer.digest(files)

      Importer.import(project, files: files, revision: revision(repository, folder), source: 'repository',
                               folder: folder)
    end

    # The first folder with template files: [folder, { name => content }].
    def read(repository)
      FOLDERS.each do |folder|
        files = read_folder(repository, folder)
        return [folder, files] if files.any?
      end
      [nil, {}]
    end

    # Some adapters fail on a folder that doesn't exist: then it has no files.
    def read_folder(repository, folder)
      entries = Array(repository.entries(folder, nil)).select(&:is_file?).select { |entry| Parser.kind(entry.name) }
      entries.to_h { |entry| [entry.name, content(repository, entry)] }
    rescue Redmine::Scm::Adapters::CommandFailed => e
      Rails.logger.warn("redmine_issue_template: #{repository.project.identifier}: #{folder}: #{e.message}")
      {}
    end

    # A file too large to be a template is not read: it is reported as too
    # long (Parser::TOO_LONG).
    def content(repository, entry)
      return Parser::TOO_LONG if entry.size.to_i > Parser::MAX_LENGTH * 4

      repository.cat(entry.path, nil).to_s
    end

    # The last revision that changed the folder, when the adapter can tell.
    def revision(repository, folder)
      repository.latest_changesets(folder, nil, 1).first&.identifier
    rescue StandardError
      nil
    end

    # The repository has no templates any more: files that came from it go
    # away; files edited in the project settings stay.
    def clear(project, current)
      return nil unless current.kind == 'repository'

      Importer.import(project, files: {}, source: 'manual')
    end
  end
end
