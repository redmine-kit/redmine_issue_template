# frozen_string_literal: true

# The template chooser of "New issue" (#index) and, in the project settings,
# the import from the repository and the files edited in Redmine. The
# settings' actions also answer the new UI's kit requests (redmine_kit_ui,
# JSON with the browser's session): the same checks, 201 or 204 for a save,
# 422 with Redmine's messages, 403 where Redmine's page refuses.
class IssueTemplatesController < ApplicationController
  include RedmineKit::IssueTemplate::SettingsParams

  menu_item :new_issue, only: :index

  before_action :find_project_by_project_id
  before_action :authorize_chooser, only: :index
  before_action :authorize, except: :index
  before_action :find_file, only: %i[show edit update destroy]
  before_action :require_manual, only: %i[settings new create edit update destroy preview]

  # What Redmine's issue form needs, for the preview.
  helper :issues, :journals, :projects, :custom_fields, :issue_relations, :watchers, :attachments
  helper IssueTemplateFormHelper

  # The settings tab's data for the new UI (GET /projects/:id/issue_templates.json).
  def files
    return redirect_to_settings unless request.format.json?

    render json: { issue_templates: RedmineKit::IssueTemplate::SettingsTab.new(@project).to_h }
  end

  def index
    @set = RedmineKit::IssueTemplate::TemplateSet.for(@project)
    @carried = request.query_parameters.except('issue_template')
    @blank = @set.config.blank_issues_enabled? || User.current.allowed_to?(:manage_issue_templates, @project)
  end

  # The chooser's settings from the project settings: the config file the
  # chooser reads, made again from the form and checked as an edited file.
  def settings
    path = RedmineKit::IssueTemplate::TemplateSet.for(@project).config.path || 'config.yml'
    file = nil
    saved = save_files do
      file = IssueTemplateFile.find_or_initialize_by(project_id: @project.id, path: path)
      file.content = chooser_config_content
      file.save(context: :settings)
    end
    return render_saved(saved, file) if request.format.json?

    settings_flash(saved, file)
    redirect_to_settings
  end

  # "Import": the template folder of the project's repository.
  def sync
    kind, message = sync_result
    if request.format.json?
      return render json: { errors: [message] }, status: :unprocessable_content if kind == :error

      return render json: { kind: kind, message: message }
    end

    flash[kind] = message
    redirect_to_settings
  end

  def new
    @file = IssueTemplateFile.new(project: @project)
  end

  def create
    @file = IssueTemplateFile.new(project: @project, **file_params)
    return render_with_preview(:new) if params[:preview]

    saved = save_files { @file.save(context: :settings) }
    return render_saved(saved, @file, created: true) if request.format.json?

    if saved
      flash[:notice] = l(:notice_successful_create)
      redirect_to_settings
    else
      render :new
    end
  end

  # A file read-only, with where it came from. The new UI's JSON has the
  # file's preview too (KitPreview).
  def show
    if request.format.json?
      data = RedmineKit::IssueTemplate::SettingsTab.new(@project).file_data(@file)
      preview = RedmineKit::IssueTemplate::KitPreview.new(@project, @file).to_h[:preview]
      return render json: { issue_template_file: data.merge(preview: preview) }
    end

    @source = IssueTemplateSource.find_by(project_id: @project.id)
    build_preview(@file)
  end

  def edit; end

  def update
    @file.attributes = file_params
    return render_with_preview(:edit) if params[:preview]

    saved = save_files { @file.save(context: :settings) }
    return render_saved(saved, @file) if request.format.json?

    if saved
      flash[:notice] = l(:notice_successful_update)
      redirect_to_settings
    else
      render :edit
    end
  end

  # The new UI's preview of a file as typed in its form, without saving
  # (POST /projects/:id/issue_templates/preview.json { issue_template_file:
  # { id, path, content } }): the file's own errors (its name) and the
  # template's messages and preview (KitPreview), as Redmine's form shows
  # them with its preview button.
  def preview
    file = previewed_file
    return render_404 unless file

    file.attributes = file_params
    render json: { preview: RedmineKit::IssueTemplate::KitPreview.typed(@project, file) }
  end

  def destroy
    save_files { @file.destroy }
    return head :no_content if request.format.json?

    flash[:notice] = l(:notice_successful_delete)
    redirect_to_settings
  end

  private

  # The import's outcome: [the flash's kind, Redmine's message].
  def sync_result
    if @project.repository.nil?
      [:error, l(:error_issue_template_no_repository)]
    elsif RedmineKit::IssueTemplate::RepositorySource.sync(@project, force: true)
      [:notice, l(:notice_issue_template_synced)]
    else
      [:warning, l(:warning_issue_template_nothing_to_import)]
    end
  end

  # The page again with the preview, without saving.
  def render_with_preview(view)
    build_preview(@file) if @file.valid?(:settings)
    render view
  end

  # The chooser and the New issue form as they would be with the file:
  # @preview (the chooser's locals) and @issue, or @preview_errors.
  def build_preview(file)
    set = file.parse_with_others
    @preview_errors = file.errors_in(set)
    return if @preview_errors.any?

    if RedmineKit::IssueTemplate::Parser.kind(file.path) == :config
      @preview = { templates: set.usable, config: set.config, blank: set.config.blank_issues_enabled? }
    else
      preview_template(set.templates.detect { |template| template.path == file.path })
    end
  end

  def preview_template(template)
    @preview = { templates: [template], config: RedmineKit::IssueTemplate::ChooserConfig.default, blank: false }
    @issue = RedmineKit::IssueTemplate::IssueTemplateDefaults.new(template, @project).new_issue
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
  end

  # The chooser needs what Redmine's own new issue form needs.
  def authorize_chooser
    return deny_access unless @project.module_enabled?(:issue_templates)

    deny_access unless User.current.allowed_to?(:add_issues, @project)
  end

  # Changes the project's files one change at a time per project. The block
  # returns whether it succeeded. Files first made here are "manual" ones.
  def save_files
    IssueTemplateFile.transaction do
      @project.lock!
      raise ActiveRecord::Rollback unless yield

      source = IssueTemplateSource.for(@project)
      source.update!(kind: 'manual') if source.new_record?
      true
    end
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
    if request.format.json?
      return render json: { errors: [l(:error_issue_template_managed_elsewhere)] }, status: :forbidden
    end

    flash[:error] = l(:error_issue_template_managed_elsewhere)
    redirect_to_settings
  end

  def redirect_to_settings
    redirect_to settings_project_path(@project, tab: 'issue_templates')
  end
end
