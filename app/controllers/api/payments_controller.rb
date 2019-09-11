# frozen_string_literal: true

# API Controller for handling payments process in the front-end
class API::PaymentsController < API::ApiController
  before_action :authenticate_user!

  ##
  # Client requests to confirm a card payment will ask this endpoint.
  # It will check for the need of a strong customer authentication (SCA) to confirm the payment or confirm that the payment
  # was successfully made. After the payment was made, the reservation/subscription will be created
  ##
  def confirm_payment
    render(json: { error: 'Online payment is disabled' }, status: :unauthorized) and return if Rails.application.secrets.fablab_without_online_payments

    begin
      if params[:payment_method_id].present?
        check_coupon
        check_plan

        # Create the PaymentIntent
        intent = Stripe::PaymentIntent.create(
          payment_method: params[:payment_method_id],
          amount: card_amount,
          currency: Rails.application.secrets.stripe_currency,
          confirmation_method: 'manual',
          confirm: true,
          customer: current_user.stp_customer_id
        )
      elsif params[:payment_intent_id].present?
        intent = Stripe::PaymentIntent.confirm(params[:payment_intent_id])
      end
    rescue Stripe::CardError => e
      # Display error on client
      res = { status: 200, json: { error: e.message } }
    rescue InvalidCouponError
      res = { json: { coupon_code: 'wrong coupon code or expired' }, status: :unprocessable_entity }
    rescue InvalidGroupError
      res = { json: { plan_id: 'this plan is not compatible with your current group' }, status: :unprocessable_entity }
    end

    if intent&.status == 'succeeded'
      if params[:cart_items][:reservation]
        res = on_reservation_success(intent)
      elsif params[:cart_items][:subscription]
        res = on_subscription_success(intent)
      end
    end

    render generate_payment_response(intent, res)
  end

  private

  def on_reservation_success(intent)
    @reservation = Reservation.new(reservation_params)
    is_reserve = Reservations::Reserve.new(current_user.id, current_user.invoicing_profile.id)
                                      .pay_and_save(@reservation, coupon: coupon_params[:coupon_code], payment_intent_id: intent.id)
    Stripe::PaymentIntent.update(
      intent.id,
      description: "Invoice reference: #{@reservation.invoice.reference}"
    )

    if is_reserve
      SubscriptionExtensionAfterReservation.new(@reservation).extend_subscription_if_eligible

      { template: 'api/reservations/show', status: :created, location: @reservation }
    else
      { json: @reservation.errors, status: :unprocessable_entity }
    end
  end

  def on_subscription_success(intent)
    @subscription = Subscription.new(subscription_params)
    is_subscribe = Subscriptions::Subscribe.new(current_user.invoicing_profile.id, current_user.id)
                                           .pay_and_save(@subscription, coupon: coupon_params[:coupon_code], invoice: true, payment_intent_id: intent.id)

    Stripe::PaymentIntent.update(
      intent.id,
      description: "Invoice reference: #{@subscription.invoices.first.reference}"
    )

    if is_subscribe
      { template: 'api/subscriptions/show', status: :created, location: @subscription }
    else
      { json: @subscription.errors, status: :unprocessable_entity }
    end
  end

  def generate_payment_response(intent, res = nil)
    return res unless res.nil?

    if intent.status == 'requires_action' && intent.next_action.type == 'use_stripe_sdk'
      # Tell the client to handle the action
      {
        status: 200,
        json: {
          requires_action: true,
          payment_intent_client_secret: intent.client_secret
        }
      }
    elsif intent.status == 'succeeded'
      # The payment didn't need any additional actions and is completed!
      # Handle post-payment fulfillment
      { status: 200, json: { success: true } }
    else
      # Invalid status
      { status: 500, json: { error: 'Invalid PaymentIntent status' } }
    end
  end

  def get_wallet_debit(user, total_amount)
    wallet_amount = (user.wallet.amount * 100).to_i
    wallet_amount >= total_amount ? total_amount : wallet_amount
  end

  def card_amount
    if params[:cart_items][:reservation]
      reservable = cart_items_params[:reservable_type].constantize.find(cart_items_params[:reservable_id])
      plan_id = cart_items_params[:plan_id]
      slots = cart_items_params[:slots_attributes] || []
      nb_places = cart_items_params[:nb_reserve_places]
      tickets = cart_items_params[:tickets_attributes]
    else
      raise NotImplementedError unless params[:cart_items][:subscription]

      reservable = nil
      plan_id = subscription_params[:plan_id]
      slots = []
      nb_places = nil
      tickets = nil
    end

    price_details = Price.compute(false,
                                  current_user,
                                  reservable,
                                  slots,
                                  plan_id,
                                  nb_places,
                                  tickets,
                                  coupon_params[:coupon_code])

    # Subtract wallet amount from total
    total = price_details[:total]
    wallet_debit = get_wallet_debit(current_user, total)
    total - wallet_debit
  end

  def check_coupon
    return if coupon_params[:coupon_code].nil?

    coupon = Coupon.find_by(code: coupon_params[:coupon_code])
    raise InvalidCouponError if coupon.nil? || coupon.status(current_user.id) != 'active'
  end

  def check_plan
    plan_id = if params[:cart_items][:subscription]
                subscription_params[:plan_id]
              elsif params[:cart_items][:reservation]
                reservation_params[:plan_id]
              end

    return unless plan_id

    plan = Plan.find(plan_id)
    raise InvalidGroupError if plan.group_id != current_user.group_id
  end

  def reservation_params
    params[:cart_items].require(:reservation).permit(:reservable_id, :reservable_type, :plan_id, :nb_reserve_places,
                                                     tickets_attributes: %i[event_price_category_id booked],
                                                     slots_attributes: %i[id start_at end_at availability_id offered])
  end

  def subscription_params
    params[:cart_items].require(:subscription).permit(:plan_id)
  end

  def cart_items_params
    params[:cart_items].require(:reservation).permit(:reservable_id, :reservable_type, :plan_id, :user_id, :nb_reserve_places,
                                                     tickets_attributes: %i[event_price_category_id booked],
                                                     slots_attributes: %i[id start_at end_at availability_id offered])
  end

  def coupon_params
    params.require(:cart_items).permit(:coupon_code)
  end
end
