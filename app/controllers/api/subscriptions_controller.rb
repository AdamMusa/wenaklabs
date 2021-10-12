# frozen_string_literal: true

# API Controller for resources of type Subscription
class API::SubscriptionsController < API::ApiController
  before_action :set_subscription, only: %i[show payment_details edit update destroy]
  before_action :authenticate_user!

  def show
    authorize @subscription
  end

  def update
    authorize @subscription

    res = Subscriptions::Subscribe.new(current_user.invoicing_profile.id)
                                  .extend_subscription(@subscription, subscription_update_params[:expired_at])
    if res.is_a?(Subscription)
      @subscription = res
      render status: :created
    elsif res
      render status: :ok
    else
      render status: :unprocessable_entity
    end
  end

  def payment_details
    authorize @subscription
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_update_params
    params.require(:subscription).permit(:expired_at)
  end
end
