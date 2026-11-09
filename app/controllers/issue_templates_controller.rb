# frozen_string_literal: true

# The template chooser of "New issue" (#index) and, in the project settings,
# the import from the repository and the files edited in Redmine.
class IssueTemplatesController < ApplicationController
  menu_item :new_issue, only: :index

  before_action :find_project_by_project_id
  before_action :authorize_chooser, only: :index
  before_action :authorize, except: :index
  before_action :find_file, only: %i[edit update destroy]
  before_action :require_manual, only: %i[new create edit update destroy]

  helper :issues

  def index
    @set = RedmineIssueTemplate::TemplateSet.for(@project)
    @carried = request.query_parameters.except('issue_template')
    @blank = @set.config.blank_issues_enabled? || User.current.allowed_to?(:manage_issue_templates, @project)
    @maintainers_only = !@set.config.blank_issues_enabled?
  end

  # "Import now": the template folder of the project's repository.
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
    if @file.save
      RedmineIssueTemplate::Importer.refresh(@project)
      flash[:notice] = l(:notice_successful_create)
      redirect_to_settings
    else
      render :new
    end
  end

  def edit; end

  def update
    @file.attributes = { path: params.dig(:issue_template_file, :path),
                         content: params.dig(:issue_template_file, :content).to_s }
    if @file.save
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
