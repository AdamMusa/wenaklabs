class Reservation < ActiveRecord::Base
  include NotifyWith::NotificationAttachedObject

  belongs_to :statistic_profile

  has_many :slots_reservations, dependent: :destroy
  has_many :slots, through: :slots_reservations

  accepts_nested_attributes_for :slots, allow_destroy: true
  belongs_to :reservable, polymorphic: true

  has_many :tickets
  accepts_nested_attributes_for :tickets, allow_destroy: false

  has_one :invoice, -> { where(type: nil) }, as: :invoiced, dependent: :destroy

  validates_presence_of :reservable_id, :reservable_type
  validate :machine_not_already_reserved, if: -> { reservable.is_a?(Machine) }
  validate :training_not_fully_reserved, if: -> { reservable.is_a?(Training) }

  attr_accessor :plan_id, :subscription

  after_commit :notify_member_create_reservation, on: :create
  after_commit :notify_admin_member_create_reservation, on: :create
  after_save :update_event_nb_free_places, if: proc { |reservation| reservation.reservable_type == 'Event' }
  after_create :debit_user_wallet

  ##
  # Generate an array of {Stripe::InvoiceItem} with the elements in the current reservation, price included.
  # The training/machine price is depending of the member's group, subscription and credits already used
  # @param on_site {Boolean} true if an admin triggered the call
  # @param coupon_code {String} pass a valid code to appy a coupon
  ##
  def generate_invoice_items(on_site = false, coupon_code = nil)
    # prepare the plan
    plan = if user.subscribed_plan
             user.subscribed_plan
           elsif plan_id
             Plan.find(plan_id)
           else
             nil
           end

    # check that none of the reserved availabilities was locked
    slots.each do |slot|
      raise LockedError if slot.availability.lock
    end

    case reservable

    # === Machine reservation ===
    when Machine
      base_amount = reservable.prices.find_by(group_id: user.group_id, plan_id: plan.try(:id)).amount
      users_credits_manager = UsersCredits::Manager.new(reservation: self, plan: plan)

      slots.each_with_index do |slot, index|
        description = reservable.name +
                      " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"

        ii_amount = base_amount # ii_amount default to base_amount

        if users_credits_manager.will_use_credits?
          ii_amount = index < users_credits_manager.free_hours_count ? 0 : base_amount
        end

        ii_amount = 0 if slot.offered && on_site # if it's a local payment and slot is offered free

        invoice.invoice_items.push InvoiceItem.new(
          amount: ii_amount,
          description: description
        )
      end

    # === Training reservation ===
    when Training
      base_amount = reservable.amount_by_group(user.group_id).amount

      # be careful, variable plan can be the user's plan OR the plan user is currently purchasing
      users_credits_manager = UsersCredits::Manager.new(reservation: self, plan: plan)
      base_amount = 0 if users_credits_manager.will_use_credits?

      slots.each do |slot|
        description = reservable.name +
                      " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"
        ii_amount = base_amount
        ii_amount = 0 if slot.offered && on_site
        invoice.invoice_items.push InvoiceItem.new(
          amount: ii_amount,
          description: description
        )
      end

    # === Event reservation ===
    when Event
      amount = reservable.amount * nb_reserve_places
      tickets.each do |ticket|
        amount += ticket.booked * ticket.event_price_category.amount
      end
      slots.each do |slot|
        description = "#{reservable.name}\n"
        description += if slot.start_at.to_date != slot.end_at.to_date
                         I18n.t('events.from_STARTDATE_to_ENDDATE',
                                STARTDATE: I18n.l(slot.start_at.to_date, format: :long),
                                ENDDATE: I18n.l(slot.end_at.to_date, format: :long)) + ' ' +
                           I18n.t('events.from_STARTTIME_to_ENDTIME',
                                  STARTTIME: I18n.l(slot.start_at, format: :hour_minute),
                                  ENDTIME: I18n.l(slot.end_at, format: :hour_minute))
                       else
                         "#{I18n.l slot.start_at.to_date, format: :long} #{I18n.l slot.start_at, format: :hour_minute}" \
                                        " - #{I18n.l slot.end_at, format: :hour_minute}"
                       end
        ii_amount = amount
        ii_amount = 0 if slot.offered && on_site
        invoice.invoice_items.push InvoiceItem.new(
          amount: ii_amount,
          description: description
        )
      end

    # === Space reservation ===
    when Space
      base_amount = reservable.prices.find_by(group_id: user.group_id, plan_id: plan.try(:id)).amount
      users_credits_manager = UsersCredits::Manager.new(reservation: self, plan: plan)

      slots.each_with_index do |slot, index|
        description = reservable.name + " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"

        ii_amount = base_amount # ii_amount default to base_amount

        if users_credits_manager.will_use_credits?
          ii_amount = index < users_credits_manager.free_hours_count ? 0 : base_amount
        end

        ii_amount = 0 if slot.offered && on_site # if it's a local payment and slot is offered free

        invoice.invoice_items.push InvoiceItem.new(
          amount: ii_amount,
          description: description
        )
      end

    # === Unknown reservation type ===
    else
      raise NotImplementedError

    end

    # === Coupon ===
    unless coupon_code.nil?
      @coupon = Coupon.find_by(code: coupon_code)
      raise InvalidCouponError if @coupon.nil? || @coupon.status(user.id) != 'active'

      total = cart_total

      discount = if @coupon.type == 'percent_off'
                   (total * @coupon.percent_off / 100).to_i
                 elsif @coupon.type == 'amount_off'
                   @coupon.amount_off
                 else
                   raise InvalidCouponError
                 end
    end

    @wallet_amount_debit = wallet_amount_debit
    # if @wallet_amount_debit != 0 && !on_site
    #   invoice_items << Stripe::InvoiceItem.create(
    #     customer: user.stp_customer_id,
    #     amount: -@wallet_amount_debit.to_i,
    #     currency: Rails.application.secrets.stripe_currency,
    #     description: "wallet -#{@wallet_amount_debit / 100.0}"
    #   )
    # end

    true
  end

  # check reservation amount total and strip invoice total to pay is equal
  # @param stp_invoice[Stripe::Invoice]
  # @param coupon_code[String]
  # return Boolean
  def is_equal_reservation_total_and_stp_invoice_total(stp_invoice, coupon_code = nil)
    compute_amount_total_to_pay(coupon_code) == stp_invoice.total
  end

  def clear_payment_info(card, invoice)
    card&.delete
    if invoice
      invoice.closed = true
      invoice.save
    end
  rescue Stripe::InvalidRequestError => e
    logger.error e
  rescue Stripe::AuthenticationError => e
    logger.error e
  rescue Stripe::APIConnectionError => e
    logger.error e
  rescue Stripe::StripeError => e
    logger.error e
  rescue StandardError => e
    logger.error e
  end

  def clean_pending_strip_invoice_items
    pending_invoice_items = Stripe::InvoiceItem.list(customer: user.stp_customer_id, limit: 100).data.select { |ii| ii.invoice.nil? }
    pending_invoice_items.each(&:delete)
  end

  def save_with_payment(operator_profile_id, coupon_code = nil, payment_intent_id = nil)
    method = InvoicingProfile.find(operator_profile_id)&.user&.admin? ? nil : 'stripe'

    build_invoice(
      invoicing_profile: user.invoicing_profile,
      statistic_profile: user.statistic_profile,
      operator_profile_id: operator_profile_id,
      stp_payment_intent_id: payment_intent_id,
      payment_method: method
    )
    generate_invoice_items(true, coupon_code)

    return false unless valid?

    if plan_id
      self.subscription = Subscription.find_or_initialize_by(statistic_profile_id: statistic_profile_id)
      subscription.attributes = { plan_id: plan_id, statistic_profile_id: statistic_profile_id, expiration_date: nil }
      if subscription.save_with_payment(operator_profile_id, false)
        invoice.invoice_items.push InvoiceItem.new(
          amount: subscription.plan.amount,
          description: subscription.plan.name,
          subscription_id: subscription.id
        )
        set_total_and_coupon(coupon_code)
        save!
      else
        errors[:card] << subscription.errors[:card].join
        return false
      end
    else
      set_total_and_coupon(coupon_code)
      save!
    end

    UsersCredits::Manager.new(reservation: self).update_credits
    true
  end

  def total_booked_seats
    total = nb_reserve_places
    total += tickets.map(&:booked).map(&:to_i).reduce(:+) if tickets.count.positive?

    total
  end

  def user
    statistic_profile.user
  end

  private

  def machine_not_already_reserved
    already_reserved = false
    slots.each do |slot|
      same_hour_slots = Slot.joins(:reservations).where(
        reservations: { reservable_type: reservable_type, reservable_id: reservable_id },
        start_at: slot.start_at,
        end_at: slot.end_at,
        availability_id: slot.availability_id,
        canceled_at: nil
      )
      if same_hour_slots.any?
        already_reserved = true
        break
      end
    end
    errors.add(:machine, 'already reserved') if already_reserved
  end

  def training_not_fully_reserved
    slot = slots.first
    errors.add(:training, 'already fully reserved') if Availability.find(slot.availability_id).completed?
  end

  private

  def notify_member_create_reservation
    NotificationCenter.call type: 'notify_member_create_reservation',
                            receiver: user,
                            attached_object: self
  end

  def notify_admin_member_create_reservation
    NotificationCenter.call type: 'notify_admin_member_create_reservation',
                            receiver: User.admins,
                            attached_object: self
  end

  def update_event_nb_free_places
    if reservable_id_was.blank?
      # simple reservation creation, we subtract the number of booked seats from the previous number
      nb_free_places = reservable.nb_free_places - total_booked_seats
    else
      # reservation moved from another date (for recurring events)
      seats = total_booked_seats

      reservable_was = Event.find(reservable_id_was)
      nb_free_places = reservable_was.nb_free_places + seats
      reservable_was.update_columns(nb_free_places: nb_free_places)
      nb_free_places = reservable.nb_free_places - seats
    end
    reservable.update_columns(nb_free_places: nb_free_places)
  end

  def cart_total
    total = (invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+) or 0)
    if plan_id.present?
      plan = Plan.find(plan_id)
      total += plan.amount
    end
    total
  end

  def wallet_amount_debit
    total = cart_total
    total = CouponService.new.apply(total, @coupon, user.id) if @coupon

    wallet_amount = (user.wallet.amount * 100).to_i

    wallet_amount >= total ? total : wallet_amount
  end

  def debit_user_wallet
    return unless @wallet_amount_debit.present? && @wallet_amount_debit != 0

    amount = @wallet_amount_debit / 100.0
    wallet_transaction = WalletService.new(user: user, wallet: user.wallet).debit(amount, self)
    # wallet debit success
    raise DebitWalletError unless wallet_transaction

    invoice.set_wallet_transaction(@wallet_amount_debit, wallet_transaction.id)
  end

  # this function only use for compute total of reservation before save
  def compute_amount_total_to_pay(coupon_code = nil)
    total = invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+)
    unless coupon_code.nil?
      cp = Coupon.find_by(code: coupon_code)
      raise InvalidCouponError unless !cp.nil? && cp.status(user.id) == 'active'

      total = CouponService.new.apply(total, cp, user.id)
    end
    total - wallet_amount_debit
  end

  ##
  # Set the total price to the reservation's invoice, summing its whole items.
  # Additionally a coupon may be applied to this invoice to make a discount on the total price
  # @param [coupon_code] {String} optional coupon code to apply to the invoice
  ##
  def set_total_and_coupon(coupon_code = nil)
    total = invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+)

    unless coupon_code.nil?
      cp = Coupon.find_by(code: coupon_code)
      raise InvalidCouponError unless !cp.nil? && cp.status(user.id) == 'active'

      total = CouponService.new.apply(total, cp, user.id)
      invoice.coupon_id = cp.id
    end

    invoice.total = total
  end
end
