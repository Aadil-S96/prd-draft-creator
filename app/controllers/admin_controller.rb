class AdminController < ApplicationController
  before_action :require_admin

  def dashboard
    @users = User.recent.includes(:projects)
    @projects = Project.recent.includes(:user).limit(50)
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to projects_path, alert: "Access denied"
    end
  end
end
