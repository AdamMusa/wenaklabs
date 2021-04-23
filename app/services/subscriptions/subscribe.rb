# frozen_string_literal: true

# Provides helper methods for Subscription actions
class Subscriptions::Subscribe
  attr_accessor :user_id, :operator_profile_id

  def initialize(operator_profile_id, user_id = nil)
    @user_id = user_id
    @operator_profile_id = operator_profile_id
  end

  ##
  # @param subscription {Subscription}
  # @param payment_details {Hash} as generated by ShoppingCart.total
  # @param payment_id {String} from the payment gateway
  # @param payment_type {String} the object type of payment_id
  # @param schedule {Boolean}
  # @param payment_method {String}
  ##
  def pay_and_save(subscription, payment_details: nil, payment_id: nil, payment_type: nil, schedule: false, payment_method: nil)
    return false if user_id.nil?

    user = User.find(user_id)
    subscription.statistic_profile_id = StatisticProfile.find_by(user_id: user_id).id

    ActiveRecord::Base.transaction do
      subscription.init_save
      raise InvalidSubscriptionError unless subscription&.persisted?

      payment = if schedule
                  generate_schedule(subscription: subscription,
                                    total: payment_details[:before_coupon],
                                    operator_profile_id: operator_profile_id,
                                    user: user,
                                    payment_method: payment_method,
                                    coupon: payment_details[:coupon],
                                    payment_id: payment_id,
                                    payment_type: payment_type)
                else
                  generate_invoice(subscription,
                                   operator_profile_id,
                                   payment_details,
                                   payment_id: payment_id,
                                   payment_type: payment_type,
                                   payment_method: payment_method)
                end
      WalletService.debit_user_wallet(payment, user, subscription)
      payment.save
      payment.post_save(payment_id)
    end
    true
  end

  def extend_subscription(subscription, new_expiration_date, free_days)
    return subscription.free_extend(new_expiration_date, @operator_profile_id) if free_days

    new_sub = Subscription.create(
      plan_id: subscription.plan_id,
      statistic_profile_id: subscription.statistic_profile_id,
      expiration_date: new_expiration_date
    )
    if new_sub.save
      schedule = subscription.original_payment_schedule

      cs = CartService.new(current_user)
      cart = cs.from_hash(customer_id: @user_id,
                          subscription: {
                            plan_id: subscription.plan_id
                          },
                          payment_schedule: !schedule.nil?)
      details = cart.total

      payment = if schedule
                  generate_schedule(subscription: new_sub,
                                    total: details[:before_coupon],
                                    operator_profile_id: operator_profile_id,
                                    user: new_sub.user,
                                    payment_method: schedule.payment_method,
                                    payment_id: schedule.gateway_payment_mean&.id,
                                    payment_type: schedule.gateway_payment_mean&.class)
                else
                  generate_invoice(subscription,
                                   operator_profile_id,
                                   details)
                end
      payment.save
      payment.post_save(schedule&.stp_setup_intent_id)
      UsersCredits::Manager.new(user: new_sub.user).reset_credits
      return new_sub
    end
    false
  end

  private

  ##
  # Generate the invoice for the given subscription
  ##
  def generate_schedule(subscription: nil, total: nil, operator_profile_id: nil, user: nil, payment_method: nil, coupon: nil,
                        payment_id: nil, payment_type: nil)
    operator = InvoicingProfile.find(operator_profile_id)&.user

    PaymentScheduleService.new.create(
      subscription,
      total,
      coupon: coupon,
      operator: operator,
      payment_method: payment_method,
      user: user,
      payment_id: payment_id,
      payment_type: payment_type
    )
  end

  ##
  # Generate the invoice for the given subscription
  ##
  def generate_invoice(subscription, operator_profile_id, payment_details, payment_id: nil, payment_type: nil, payment_method: nil)
    InvoicesService.create(
      payment_details,
      operator_profile_id,
      subscription: subscription,
      payment_id: payment_id,
      payment_type: payment_type,
      payment_method: payment_method
    )
  end

end
