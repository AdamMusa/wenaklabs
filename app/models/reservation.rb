class Reservation < ActiveRecord::Base
  include NotifyWith::NotificationAttachedObject

  belongs_to :user
  has_many :slots, dependent: :destroy
  accepts_nested_attributes_for :slots, allow_destroy: true
  belongs_to :reservable, polymorphic: true

  has_one :invoice, -> {where(type: nil)}, as: :invoiced, dependent: :destroy

  validates_presence_of :reservable_id, :reservable_type
  validate :machine_not_already_reserved, if: -> { self.reservable.is_a?(Machine) }
  validate :training_not_fully_reserved, if: -> { self.reservable.is_a?(Training) }

  attr_accessor :card_token, :plan_id, :subscription

  after_commit :notify_member_create_reservation, on: :create
  after_commit :notify_admin_member_create_reservation, on: :create
  after_save :update_event_nb_free_places, if: Proc.new { |reservation| reservation.reservable_type == 'Event' }

  #
  # Generate an array of {Stripe::InvoiceItem} with the elements in the current reservation, price included.
  # The training/machine price is depending of the member's group, subscription and credits already used
  # @param on_site {Boolean} true if an admin triggered the call
  #
  def generate_invoice_items(on_site = false)

    # returning array
    invoice_items = []

    # prepare the plan
    if user.subscribed_plan
      plan = user.subscribed_plan
      new_plan_being_bought = false
    elsif plan_id
      plan = Plan.find(plan_id)
      new_plan_being_bought = true
    else
      plan = nil
    end


    case reservable

      # === Machine reservation ===
      when Machine
        base_amount = reservable.prices.find_by(group_id: user.group_id, plan_id: plan.try(:id)).amount
        users_credits_manager = UsersCredits::Manager.new(reservation: self, plan: plan)

        slots.each_with_index do |slot, index|
          description = reservable.name + " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"

          ii_amount = base_amount # ii_amount default to base_amount

          if users_credits_manager.will_use_credits?
            ii_amount = (index < users_credits_manager.free_hours_count) ? 0 : base_amount
          end

          ii_amount = 0 if slot.offered and on_site # if it's a local payment and slot is offered free

          unless on_site # if it's local payment then do not create Stripe::InvoiceItem
            ii = Stripe::InvoiceItem.create(
                customer: user.stp_customer_id,
                amount: ii_amount,
                currency: Rails.application.secrets.stripe_currency,
                description: description
            )
            invoice_items << ii
          end
          self.invoice.invoice_items.push InvoiceItem.new(amount: ii_amount, stp_invoice_item_id: (ii.id if ii), description: description)
        end


      # === Training reservation ===
      when Training
        base_amount = reservable.amount_by_group(user.group_id).amount

        # be careful, variable plan can be the user's plan OR the plan user is currently purchasing
        users_credits_manager = UsersCredits::Manager.new(reservation: self, plan: plan)
        base_amount = 0 if users_credits_manager.will_use_credits?

        slots.each do |slot|
          description = reservable.name + " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"
          ii_amount = base_amount
          ii_amount = 0 if (slot.offered and on_site)
          unless on_site
            ii = Stripe::InvoiceItem.create(
                customer: user.stp_customer_id,
                amount: ii_amount,
                currency: Rails.application.secrets.stripe_currency,
                description: description
            )
            invoice_items << ii
          end
          self.invoice.invoice_items.push InvoiceItem.new(amount: ii_amount, stp_invoice_item_id: (ii.id if ii), description: description)
        end

      # === Event reservation ===
      when Event
        if reservable.reduced_amount and nb_reserve_reduced_places
          amount = reservable.amount * nb_reserve_places + (reservable.reduced_amount * nb_reserve_reduced_places)
        else
          amount = reservable.amount * nb_reserve_places
        end
        slots.each do |slot|
          description = reservable.name + " #{I18n.l slot.start_at, format: :long} - #{I18n.l slot.end_at, format: :hour_minute}"
          ii_amount = amount
          ii_amount = 0 if (slot.offered and on_site)
          unless on_site
            ii = Stripe::InvoiceItem.create(
                customer: user.stp_customer_id,
                amount: ii_amount,
                currency: Rails.application.secrets.stripe_currency,
                description: description
            )
            invoice_items << ii
          end
          self.invoice.invoice_items.push InvoiceItem.new(amount: ii_amount, stp_invoice_item_id: (ii.id if ii), description: description)
        end

      # === Unknown reservation type ===
      else
        raise NotImplementedError

    end

    # let's return the resulting array of items
    invoice_items
  end

  def save_with_payment
    build_invoice(user: user)
    invoice_items = generate_invoice_items
    if valid?
      # TODO: refactoring
      customer = Stripe::Customer.retrieve(user.stp_customer_id)
      if plan_id
        self.subscription = Subscription.find_or_initialize_by(user_id: user.id)
        self.subscription.attributes = {plan_id: plan_id, user_id: user.id, card_token: card_token, expired_at: nil}
        if subscription.save_with_payment(false)
          self.stp_invoice_id = invoice_items.first.refresh.invoice
          self.invoice.stp_invoice_id = invoice_items.first.refresh.invoice
          self.invoice.invoice_items.push InvoiceItem.new(amount: subscription.plan.amount, stp_invoice_item_id: subscription.stp_subscription_id, description: subscription.plan.name, subscription_id: subscription.id)
          total = invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+)
          self.invoice.total = total
          save!
          #
          # IMPORTANT NOTE: here, we don't have to create a stripe::invoice and pay it
          # because subscription.create (in subscription.rb) will pay all waiting stripe invoice items
          #
        else
          # error handling
          invoice_items.each(&:delete)
          errors[:card] << subscription.errors[:card].join
          if subscription.errors[:payment]
            errors[:payment] << subscription.errors[:payment].join
          end
          return false
        end

      else
        begin
          if invoice_items.map(&:amount).map(&:to_i).reduce(:+) > 0
            card = customer.sources.create(card: card_token)
            if customer.default_source.present?
              customer.default_source = card.id
              customer.save
            end
          end
          #
          # IMPORTANT NOTE: here, we have to create an invoice manually and pay it to pay all waiting stripe invoice items
          #
          invoice = Stripe::Invoice.create(
            customer: user.stp_customer_id,
          )
          invoice.pay
          card.delete if card
          self.stp_invoice_id = invoice.id
          self.invoice.stp_invoice_id = invoice.id
          self.invoice.total = invoice.total
          save!
        rescue Stripe::CardError => card_error
          clear_payment_info(card, invoice, invoice_items)
          logger.info card_error
          errors[:card] << card_error.message
          return false
        rescue Stripe::InvalidRequestError => e
          # Invalid parameters were supplied to Stripe's API
          clear_payment_info(card, invoice, invoice_items)
          logger.error e
          errors[:payment] << e.message
          return false
        rescue Stripe::AuthenticationError => e
          # Authentication with Stripe's API failed
          # (maybe you changed API keys recently)
          clear_payment_info(card, invoice, invoice_items)
          logger.error e
          errors[:payment] << e.message
          return false
        rescue Stripe::APIConnectionError => e
          # Network communication with Stripe failed
          clear_payment_info(card, invoice, invoice_items)
          logger.error e
          errors[:payment] << e.message
          return false
        rescue Stripe::StripeError => e
          # Display a very generic error to the user, and maybe send
          # yourself an email
          clear_payment_info(card, invoice, invoice_items)
          logger.error e
          errors[:payment] << e.message
          return false
        rescue => e
          # Something else happened, completely unrelated to Stripe
          clear_payment_info(card, invoice, invoice_items)
          logger.error e
          errors[:payment] << e.message
          return false
        end
      end

      UsersCredits::Manager.new(reservation: self).update_credits
      true
    end
  end

  def clear_payment_info(card, invoice, invoice_items)
    begin
      card.delete if card
      if invoice
        invoice.closed = true
        invoice.save
      end
      if invoice_items.size > 0
        invoice_items.each(&:delete)
      end
    rescue Stripe::InvalidRequestError => e
      logger.error e
    rescue Stripe::AuthenticationError => e
      logger.error e
    rescue Stripe::APIConnectionError => e
      logger.error e
    rescue Stripe::StripeError => e
      logger.error e
    rescue => e
      logger.error e
    end
  end


  def save_with_local_payment
    if user.invoicing_disabled?
      if valid?
        save!
        UsersCredits::Manager.new(reservation: self).update_credits
        return true
      end
    else
      build_invoice(user: user)
      generate_invoice_items(true)
    end

    if valid?
      if plan_id
        self.subscription = Subscription.find_or_initialize_by(user_id: user.id)
        self.subscription.attributes = {plan_id: plan_id, user_id: user.id, expired_at: nil}
        if subscription.save_with_local_payment(false)
          self.invoice.invoice_items.push InvoiceItem.new(amount: subscription.plan.amount, description: subscription.plan.name, subscription_id: subscription.id)
          total = invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+)
          self.invoice.total = total
          save!
        else
          errors[:card] << subscription.errors[:card].join
          return false
        end
      else
        total = invoice.invoice_items.map(&:amount).map(&:to_i).reduce(:+)
        self.invoice.total = total
        save!
      end

      UsersCredits::Manager.new(reservation: self).update_credits
      return true
    end
  end

  def machine_not_already_reserved
    already_reserved = false
    self.slots.each do |slot|
      same_hour_slots = Slot.joins(:reservation).where(
                        reservations: { reservable_type: self.reservable_type,
                                       reservable_id: self.reservable_id
                                     },
                                       start_at: slot.start_at,
                                       end_at: slot.end_at,
                                       availability_id: slot.availability_id,
                                       canceled_at: nil)
      if same_hour_slots.any?
        already_reserved = true
        break
      end
    end
    errors.add(:machine, "already reserved") if already_reserved
  end

  def training_not_fully_reserved
    slot = self.slots.first
    errors.add(:training, "already fully reserved") if Availability.find(slot.availability_id).is_completed
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
      nb_free_places = reservable.nb_free_places - nb_reserve_places - nb_reserve_reduced_places
    else
      reservable_was = Event.find(reservable_id_was)
      nb_free_places = reservable_was.nb_free_places + nb_reserve_places + nb_reserve_reduced_places
      reservable_was.update_columns(nb_free_places: nb_free_places)
      nb_free_places = reservable.nb_free_places - nb_reserve_places - nb_reserve_reduced_places
    end
    reservable.update_columns(nb_free_places: nb_free_places)
  end
end
