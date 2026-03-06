class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :update]

  def index
    @projects = current_user.admin? ? Project.recent.includes(:user) : current_user.projects.recent
  end

  def show
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project was successfully updated."
    else
      flash.now[:alert] = "Failed to update project."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = if current_user.admin?
                 Project.find(params[:id])
               else
                 current_user.projects.find(params[:id])
               end
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "Project not found"
  end

  def project_params
    params.require(:project).permit(:status, :owner)
  end
end
