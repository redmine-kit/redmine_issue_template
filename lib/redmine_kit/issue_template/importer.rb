# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # Stores a project's template files and where they came from. The entry
    # point for other plugins too: redmine_kit_github calls #import with the files
    # of a push (docs/sync.md#redmine-kit-github).
    module Importer
      module_function

      # Replaces the project's files with the given ones.
      #   files:    { "bug.yml" => "...", ... } (file names in the folder)
      #   revision: the commit they come from (shown in the settings)
      #   source:   "repository", "github" or "manual"
      #   folder:   the folder they were read from: ".redmine/ISSUE_TEMPLATE"
      #             (FOLDERS); files of another folder are refused
      # Returns the IssueTemplateSource; IssueTemplateSource.messages_for gives
      # the errors and warnings. With a block, the block is given the stored
      # IssueTemplateSource and the files' digest inside the project's lock,
      # and nothing is imported (nil) when it returns true: a decision on what
      # is stored holds only there, since another import may have committed
      # since it was read.
      def import(project, files:, revision: nil, source: 'repository', folder: nil)
        raise ArgumentError, "unknown source: #{source}" unless SOURCES.include?(source)
        raise ArgumentError, "unsupported folder: #{folder}" if folder && !FOLDERS.include?(folder)

        files = files.to_h { |path, content| [File.basename(path.to_s), utf8(content)] }
                     .select { |path, _| storable?(project, path) }
        files_digest = digest(files)
        record = IssueTemplateFile.transaction do
          # One import at a time per project (a fetch, the button and a push
          # can come together).
          project.lock!
          current = IssueTemplateSource.for(project)
          next nil if block_given? && yield(current, files_digest)

          store(project, files)
          current.update!(kind: source, folder: folder, revision: revision, digest: files_digest,
                          synced_at: Time.current)
          current
        end
        TemplateSet.reset! if record
        record
      end

      # The project's files replaced by these. A file too long to store is kept
      # empty, marked as too long.
      def store(project, files)
        IssueTemplateFile.where(project_id: project.id).delete_all
        files.each do |path, content|
          too_long = content.length > Parser::MAX_LENGTH
          IssueTemplateFile.create!(project: project, path: path, content: too_long ? '' : content, too_long: too_long)
        end
      end

      # Text in UTF-8, as Redmine reads the repository's files.
      def utf8(content)
        Redmine::CodesetUtil.to_utf8_by_setting(content.to_s)
      end

      # A template file with a name the project can store; others are left
      # out, so that one odd name doesn't stop the import.
      def storable?(project, path)
        return false unless Parser.kind(path)
        return true if path.length <= 255 && IssueTemplateFile::PATH.match?(path)

        Rails.logger.warn("redmine_kit_issue_template: #{project.identifier}: file name not used: #{path.inspect}")
        false
      end

      # The same for the repository's raw files and the stored ones.
      def digest(files)
        Digest::SHA256.hexdigest(files.to_h { |path, content| [path, utf8(content)] }.sort.to_s)
      end
    end
  end
end
