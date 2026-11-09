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
        entries = Array(repository.entries(folder, nil)).select(&:is_file?)
        files = entries.select { |entry| Parser.kind(entry.name) }
                       .to_h { |entry| [entry.name, repository.cat(entry.path, nil).to_s] }
        return [folder, files] if files.any?
      end
      [nil, {}]
    rescue Redmine::Scm::Adapters::CommandFailed => e
      Rails.logger.warn("redmine_issue_template: #{repository.project.identifier}: #{e.message}")
      [nil, {}]
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
