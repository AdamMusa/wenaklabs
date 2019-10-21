# frozen_string_literal: true

# API Controller for resources of type Setting
class API::SettingsController < API::ApiController
  before_action :authenticate_user!, only: :update

  def index
    @settings = Setting.where(name: names_as_string_to_array)
  end

  def update
    authorize Setting
    @setting = Setting.find_or_initialize_by(name: params[:name])
    if @setting.save && @setting.history_values.create(value: setting_params[:value], invoicing_profile: current_user.invoicing_profile)
      render status: :ok
    else
      render json: @setting.errors.full_messages, status: :unprocessable_entity
    end
  end

  def bulk_update
    authorize Setting

    @settings = []
    params[:settings].each do |setting|
      next if !setting[:name] || !setting[:value]

      db_setting = Setting.find_or_initialize_by(name: setting[:name])
      db_setting.save && db_setting.history_values.create(value: setting[:value], invoicing_profile: current_user.invoicing_profile)
      @settings.push db_setting
    end
  end

  def show
    @setting = Setting.find_or_create_by(name: params[:name])
    @show_history = params[:history] == 'true' && current_user.admin?
  end

  private

  def setting_params
    params.require(:setting).permit(:value)
  end

  def names_as_string_to_array
    params[:names][1..-2].split(',').map(&:strip).map { |param| param[1..-2] }.map(&:strip)
  end
end
