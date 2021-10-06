# frozen_string_literal: true

# API Controller for handling the payments process in the front-end, using the Stripe gateway
class API::StripeController < API::PaymentsController
  require 'stripe/helper'
  require 'stripe/service'

  before_action :check_keys, except: :online_payment_status

  ##
  # Client requests to confirm a card payment will ask this endpoint.
  # It will check for the need of a strong customer authentication (SCA) to confirm the payment or confirm that the payment
  # was successfully made. After the payment was made, the reservation/subscription will be created
  ##
  def confirm_payment
    render(json: { error: 'Bad gateway or online payment is disabled' }, status: :bad_gateway) and return unless Stripe::Helper.enabled?

    intent = nil # stripe's payment intent
    res = nil # json of the API answer

    cart = shopping_cart
    begin
      amount = debit_amount(cart) # will contains the amount and the details of each invoice lines
      if params[:payment_method_id].present?
        # Create the PaymentIntent
        intent = Stripe::PaymentIntent.create(
          {
            payment_method: params[:payment_method_id],
            amount: Stripe::Service.new.stripe_amount(amount[:amount]),
            currency: Setting.get('stripe_currency'),
            confirmation_method: 'manual',
            confirm: true,
            customer: cart.customer.payment_gateway_object.gateway_object_id
          }, { api_key: Setting.get('stripe_secret_key') }
        )
      elsif params[:payment_intent_id].present?
        intent = Stripe::PaymentIntent.confirm(params[:payment_intent_id], {}, { api_key: Setting.get('stripe_secret_key') })
      end
    rescue Stripe::CardError => e
      # Display error on client
      res = { status: 200, json: { error: e.message } }
    rescue InvalidCouponError
      res = { json: { coupon_code: 'wrong coupon code or expired' }, status: :unprocessable_entity }
    rescue InvalidGroupError
      res = { json: { plan_id: 'this plan is not compatible with your current group' }, status: :unprocessable_entity }
    end

    res = on_payment_success(intent, cart) if intent&.status == 'succeeded'

    render generate_payment_response(intent, 'payment', res)
  end

  def online_payment_status
    authorize :payment

    key = Setting.get('stripe_secret_key')
    render json: { status: false } and return unless key&.present?

    charges = Stripe::Charge.list({ limit: 1 }, { api_key: key })
    render json: { status: charges.data.length.positive? }
  rescue Stripe::AuthenticationError
    render json: { status: false }
  end

  def setup_intent
    user = User.find(params[:user_id])
    key = Setting.get('stripe_secret_key')
    @intent = Stripe::SetupIntent.create({ customer: user.payment_gateway_object.gateway_object_id }, { api_key: key })
    render json: { id: @intent.id, client_secret: @intent.client_secret }
  end

  def create_subscription
    cart = shopping_cart
    cart.items.each do |item|
      raise InvalidSubscriptionError unless item.valid?(@items)
      raise InvalidSubscriptionError unless item.to_object.errors.empty?
    end

    service = Stripe::Service.new
    method = service.attach_method_as_default(
      params[:payment_method_id],
      cart.customer.payment_gateway_object.gateway_object_id
    )

    stp_subscription = service.subscribe(method.id, cart)

    res = on_payment_success(stp_subscription, cart) if stp_subscription&.status == 'active'
    render generate_payment_response(stp_subscription.latest_invoice.payment_intent, 'subscription', res, stp_subscription.id)
  end

  def confirm_subscription
    key = Setting.get('stripe_secret_key')
    subscription = Stripe::Subscription.retrieve(params[:subscription_id], api_key: key)

    cart = shopping_cart
    if subscription&.status == 'active'
      res = on_payment_success(subscription, cart)
      render generate_payment_response(subscription, res)
    end
  rescue Stripe::InvalidRequestError => e
    render json: e, status: :unprocessable_entity
  end

  def update_card
    user = User.find(params[:user_id])
    key = Setting.get('stripe_secret_key')
    Stripe::Customer.update(user.payment_gateway_object.gateway_object_id,
                            { invoice_settings: { default_payment_method: params[:payment_method_id] } },
                            { api_key: key })
    if params[:payment_schedule_id]
      schedule = PaymentSchedule.find(params[:payment_schedule_id])
      subscription = schedule.gateway_subscription.retrieve
      Stripe::Subscription.update(subscription.id, { default_payment_method: params[:payment_method_id] }, { api_key: key })
    end
    render json: { updated: true }, status: :ok
  rescue Stripe::StripeError => e
    render json: { updated: false, error: e }, status: :unprocessable_entity
  end

  private

  def post_save(intent_id, intent_type, payment_document)
    return unless intent_type == 'Stripe::PaymentIntent'

    Stripe::PaymentIntent.update(
      intent_id,
      { description: "#{payment_document.class.name} reference: #{payment_document.reference}" },
      { api_key: Setting.get('stripe_secret_key') }
    )
  end

  def on_payment_success(intent, cart)
    super(intent.id, intent.class.name, cart)
  end

  def generate_payment_response(intent, type, res = nil, stp_subscription_id = nil)
    return res unless res.nil?

    if intent.status == 'requires_action' && intent.next_action.type == 'use_stripe_sdk'
      # Tell the client to handle the action
      {
        status: 200,
        json: {
          requires_action: true,
          payment_intent_client_secret: intent.client_secret,
          type: type,
          subscription_id: stp_subscription_id
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

  def check_keys
    key = Setting.get('stripe_secret_key')
    raise Stripe::StripeError, 'Using live keys in development mode' if key&.match(/^sk_live_/) && Rails.env.development?
  end
end
