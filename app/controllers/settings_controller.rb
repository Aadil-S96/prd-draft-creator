class SettingsController < ApplicationController
  def show
  end

  def update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "Settings updated"
    else
      flash.now[:alert] = "Failed to update settings"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:name, :notion_api_key, :notion_database_id)
  end
end
