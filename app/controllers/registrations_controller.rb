class RegistrationsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to login_path
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to projects_path, notice: "Welcome to PRD Draft Generator!"
    else
      redirect_to login_path, alert: @user.errors.full_messages.join(". ")
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
