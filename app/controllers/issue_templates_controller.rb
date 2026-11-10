# frozen_string_literal: true

# The template chooser of "New issue" (#index) and, in the project settings,
# the import from the repository and the files edited in Redmine.
class IssueTemplatesController < ApplicationController
  menu_item :new_issue, only: :index

  before_action :find_project_by_project_id
  before_action :authorize_chooser, only: :index
  before_action :authorize, except: :index
  before_action :find_file, only: %i[show edit update destroy]
  before_action :require_manual, only: %i[new create edit update destroy]

  # What Redmine's issue form needs, for the preview.
  helper :issues, :journals, :projects, :custom_fields, :issue_relations, :watchers, :attachments
  helper IssueTemplateFormHelper

  def index
    @set = RedmineIssueTemplate::TemplateSet.for(@project)
    @carried = request.query_parameters.except('issue_template')
    @blank = @set.config.blank_issues_enabled? || User.current.allowed_to?(:manage_issue_templates, @project)
  end

  # "Import": the template folder of the project's repository.
  def sync
    if @project.repository.nil?
      flash[:error] = l(:error_issue_template_no_repository)
    elsif RedmineIssueTemplate::RepositorySource.sync(@project, force: true)
      flash[:notice] = l(:notice_issue_template_synced)
    else
      flash[:warning] = l(:warning_issue_template_nothing_to_import)
    end
    redirect_to_settings
  end

  def new
    @file = IssueTemplateFile.new(project: @project)
  end

  def create
    @file = IssueTemplateFile.new(project: @project, path: params.dig(:issue_template_file, :path),
                                  content: params.dig(:issue_template_file, :content).to_s)
    return preview(:new) if params[:preview]

    if @file.save(context: :settings)
      RedmineIssueTemplate::Importer.refresh(@project)
      flash[:notice] = l(:notice_successful_create)
      redirect_to_settings
    else
      render :new
    end
  end

  # A file read-only, with where it came from.
  def show
    @source = IssueTemplateSource.find_by(project_id: @project.id)
    build_preview(@file)
  end

  def edit; end

  def update
    @file.attributes = { path: params.dig(:issue_template_file, :path),
                         content: params.dig(:issue_template_file, :content).to_s }
    return preview(:edit) if params[:preview]

    if @file.save(context: :settings)
      RedmineIssueTemplate::Importer.refresh(@project)
      flash[:notice] = l(:notice_successful_update)
      redirect_to_settings
    else
      render :edit
    end
  end

  def destroy
    @file.destroy
    RedmineIssueTemplate::Importer.refresh(@project)
    flash[:notice] = l(:notice_successful_delete)
    redirect_to_settings
  end

  private

  # The page again with the preview, without saving.
  def preview(view)
    build_preview(@file) if @file.valid?(:settings)
    render view
  end

  # The chooser and the New issue form as they would be with the file:
  # @preview (the chooser's locals) and @issue, or @preview_errors.
  def build_preview(file)
    files = IssueTemplateFile.where(project_id: @project.id).where.not(id: file.id).pluck(:path, :content).to_h
    files[file.path] = file.content.to_s
    set = RedmineIssueTemplate::Parser.parse(files)
    @preview_errors = set.messages.select { |message| message.path == file.path && message.error? }
    return if @preview_errors.any?

    if RedmineIssueTemplate::Parser.kind(file.path) == :config
      @preview = { templates: set.usable, config: set.config, blank: set.config.blank_issues_enabled? }
    else
      preview_template(set.templates.detect { |template| template.path == file.path })
    end
  end

  def preview_template(template)
    @preview = { templates: [template], config: RedmineIssueTemplate::ChooserConfig.default, blank: false }
    @issue = RedmineIssueTemplate::IssueTemplateDefaults.new(template, @project).new_issue
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
  end

  # The chooser needs what Redmine's own new issue form needs.
  def authorize_chooser
    return deny_access unless @project.module_enabled?(:issue_templates)

    deny_access unless User.current.allowed_to?(:add_issues, @project)
  end

  def find_file
    @file = IssueTemplateFile.where(project_id: @project.id).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Files from the repository or GitHub are edited there.
  def require_manual
    source = IssueTemplateSource.find_by(project_id: @project.id)
    return if source.nil? || source.manual?

    flash[:error] = l(:error_issue_template_managed_elsewhere)
    redirect_to_settings
  end

  def redirect_to_settings
    redirect_to settings_project_path(@project, tab: 'issue_templates')
  end
end
