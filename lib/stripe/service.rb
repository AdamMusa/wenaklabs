# frozen_string_literal: true

require 'payment/service'

# Stripe payement gateway
module Stripe; end

## create remote objects on stripe
class Stripe::Service < Payment::Service
  # Create the provided PaymentSchedule on Stripe, using the Subscription API
  def create_subscription(payment_schedule, setup_intent_id)
    stripe_key = Setting.get('stripe_secret_key')
    first_item = payment_schedule.ordered_items.first

    case payment_schedule.main_object.object_type
    when Reservation.name
      subscription = payment_schedule.payment_schedule_objects.find(&:subscription).object
      reservable_stp_id = payment_schedule.main_object.object.reservable&.payment_gateway_object&.gateway_object_id
    when Subscription.name
      subscription = payment_schedule.main_object.object
      reservable_stp_id = nil
    else
      raise InvalidSubscriptionError
    end

    handle_wallet_transaction(payment_schedule)

    # setup intent (associates the customer and the payment method)
    intent = Stripe::SetupIntent.retrieve(setup_intent_id, api_key: stripe_key)
    # subscription (recurring price)
    price = create_price(first_item.details['recurring'],
                         subscription.plan.payment_gateway_object.gateway_object_id,
                         nil, monthly: true)
    # other items (not recurring)
    items = subscription_invoice_items(payment_schedule, subscription, first_item, reservable_stp_id)

    stp_subscription = Stripe::Subscription.create({
                                                     customer: payment_schedule.invoicing_profile.user.payment_gateway_object.gateway_object_id,
                                                     cancel_at: (payment_schedule.ordered_items.last.due_date + 3.day).to_i,
                                                     add_invoice_items: items,
                                                     coupon: payment_schedule.coupon&.code,
                                                     items: [
                                                       { price: price[:id] }
                                                     ],
                                                     default_payment_method: intent[:payment_method]
                                                   }, { api_key: stripe_key })
    pgo = PaymentGatewayObject.new(item: payment_schedule)
    pgo.gateway_object = stp_subscription
    pgo.save!
  end

  def create_coupon(coupon_id)
    coupon = Coupon.find(coupon_id)
    stp_coupon = { id: coupon.code }
    if coupon.type == 'percent_off'
      stp_coupon[:percent_off] = coupon.percent_off
    elsif coupon.type == stripe_amount('amount_off')
      stp_coupon[:amount_off] = coupon.amount_off
      stp_coupon[:currency] = Setting.get('stripe_currency')
    end

    stp_coupon[:duration] = coupon.validity_per_user == 'always' ? 'forever' : 'once'
    stp_coupon[:redeem_by] = coupon.valid_until.to_i unless coupon.valid_until.nil?
    stp_coupon[:max_redemptions] = coupon.max_usages unless coupon.max_usages.nil?

    Stripe::Coupon.create(stp_coupon, api_key: Setting.get('stripe_secret_key'))
  end

  def delete_coupon(coupon_id)
    coupon = Coupon.find(coupon_id)
    StripeWorker.perform_async(:delete_stripe_coupon, coupon.code)
  end

  def create_or_update_product(klass, id)
    StripeWorker.perform_async(:create_or_update_stp_product, klass, id)
  rescue Stripe::InvalidRequestError => e
    raise ::PaymentGatewayError, e
  end

  def stripe_amount(amount)
    currency = Setting.get('stripe_currency')
    return amount / 100 if zero_decimal_currencies.any? { |s| s.casecmp(currency).zero? }

    amount
  end

  def process_payment_schedule_item(payment_schedule_item)
    stripe_key = Setting.get('stripe_secret_key')
    stp_subscription = payment_schedule_item.payment_schedule.gateway_subscription.retrieve
    stp_invoice = Stripe::Invoice.retrieve(stp_subscription.latest_invoice, api_key: stripe_key)
    if stp_invoice.status == 'paid'
      ##### Successfully paid
      PaymentScheduleService.new.generate_invoice(payment_schedule_item,
                                                  payment_method: 'card',
                                                  payment_id: stp_invoice.payment_intent,
                                                  payment_type: 'Stripe::PaymentIntent')
      payment_schedule_item.update_attributes(state: 'paid', payment_method: 'card')
      pgo = PaymentGatewayObject.find_or_initialize_by(item: payment_schedule_item)
      pgo.gateway_object = stp_invoice
      pgo.save!
    elsif stp_subscription.status == 'past_due' || stp_invoice.status == 'open'
      ##### Payment error
      if payment_schedule_item.state == 'new'
        # notify only for new deadlines, to prevent spamming
        NotificationCenter.call type: 'notify_admin_payment_schedule_failed',
                                receiver: User.admins_and_managers,
                                attached_object: payment_schedule_item
        NotificationCenter.call type: 'notify_member_payment_schedule_failed',
                                receiver: payment_schedule_item.payment_schedule.user,
                                attached_object: payment_schedule_item
      end
      stp_payment_intent = Stripe::PaymentIntent.retrieve(stp_invoice.payment_intent, api_key: stripe_key)
      payment_schedule_item.update_attributes(state: stp_payment_intent.status,
                                              client_secret: stp_payment_intent.client_secret)
      pgo = PaymentGatewayObject.find_or_initialize_by(item: payment_schedule_item)
      pgo.gateway_object = stp_invoice
      pgo.save!
    else
      payment_schedule_item.update_attributes(state: 'error')
    end
  end

  def pay_payment_schedule_item(payment_schedule_item)
    stripe_key = Setting.get('stripe_secret_key')
    stp_invoice = Stripe::Invoice.pay(@payment_schedule_item.payment_gateway_object.gateway_object_id, {}, { api_key: stripe_key })
    PaymentScheduleItemWorker.new.perform(@payment_schedule_item.id)

    { status: stp_invoice.status }
  rescue Stripe::StripeError => e
    stripe_key = Setting.get('stripe_secret_key')
    stp_invoice = Stripe::Invoice.retrieve(@payment_schedule_item.payment_gateway_object.gateway_object_id, api_key: stripe_key)
    PaymentScheduleItemWorker.new.perform(@payment_schedule_item.id)

    { status: stp_invoice.status, error: e }
  end

  private

  def subscription_invoice_items(payment_schedule, subscription, first_item, reservable_stp_id)
    second_item = payment_schedule.ordered_items[1]

    items = []
    if first_item.amount != second_item.amount
      unless first_item.details['adjustment']&.zero?
        # adjustment: when dividing the price of the plan / months, sometimes it forces us to round the amount per month.
        # The difference is invoiced here
        p1 = create_price(first_item.details['adjustment'],
                          subscription.plan.payment_gateway_object.gateway_object_id,
                          "Price adjustment for payment schedule #{payment_schedule.id}")
        items.push(price: p1[:id])
      end
      unless first_item.details['other_items']&.zero?
        # when taking a subscription at the same time of a reservation (space, machine or training), the amount of the
        # reservation is invoiced here.
        p2 = create_price(first_item.details['other_items'],
                          reservable_stp_id,
                          "Reservations for payment schedule #{payment_schedule.id}")
        items.push(price: p2[:id])
      end
    end

    items
  end

  def create_price(amount, stp_product_id, name, monthly: false)
    params = {
      unit_amount: stripe_amount(amount),
      currency: Setting.get('stripe_currency'),
      product: stp_product_id,
      nickname: name
    }
    params[:recurring] = { interval: 'month', interval_count: 1 } if monthly

    Stripe::Price.create(params, api_key: Setting.get('stripe_secret_key'))
  end

  def handle_wallet_transaction(payment_schedule)
    return unless payment_schedule.wallet_amount

    customer_id = payment_schedule.invoicing_profile.user.payment_gateway_object.gateway_object_id
    Stripe::Customer.update(customer_id, { balance: -payment_schedule.wallet_amount }, { api_key: Setting.get('stripe_secret_key') })
  end

  # @see https://stripe.com/docs/currencies#zero-decimal
  def zero_decimal_currencies
    %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF]
  end
end
