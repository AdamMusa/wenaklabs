require 'forwardable'

module UsersCredits
  class AlreadyUpdatedError < StandardError; end

  class Manager
    extend Forwardable
    attr_reader :manager

    def initialize(reservation: nil, user: nil, plan: nil)
      if user
        @manager = Managers::User.new(user)
      elsif reservation
        if reservation.reservable_type == 'Training'
          @manager = Managers::Training.new(reservation, plan)
        elsif reservation.reservable_type == 'Machine'
          @manager = Managers::Machine.new(reservation, plan)
        elsif reservation.reservable_type == 'Event'
          @manager = Managers::Event.new(reservation, plan)
        elsif reservation.reservable_type == 'Space'
          @manager = Managers::Space.new(reservation, plan)
        else
          raise ArgumentError, 'reservation.reservable_type must be Training, Machine, Space or Event'
        end
      else
        raise ArgumentError, 'you have to pass either a reservation or a user to initialize a UsersCredits::Manager'
      end
    end

    def_delegators :@manager, :will_use_credits?, :free_hours_count, :update_credits, :reset_credits
  end

  module Managers
    # that class is responsible for resetting users_credits of a user
    class User
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def reset_credits
        user.users_credits.destroy_all
      end
    end

    class Reservation
      attr_reader :reservation

      # a plan can be passed to do a simulation (if user didn't have a subscription YET)
      def initialize(reservation, plan)
        @reservation = reservation
        @already_updated = false
        @plan = plan
      end

      def plan
        @plan || user.subscribed_plan
      end

      def user
        reservation.user
      end

      def update_credits
        if @already_updated
          raise AlreadyUpdatedError, "update credit is not idempotent ! you can't invoke update_credits method twice."
        else
          @already_updated = true
        end
      end
    end
    private_constant :Reservation


    # that class is responsible for knowing how to update users_credit of a given user for a given reservation
    class Machine < Reservation
      # to known if a credit will be used in the context of the given reservation
      def will_use_credits?
        _will_use_credits?[0]
      end

      def free_hours_count
        _will_use_credits?[1]
      end

      def update_credits
        super

        will_use_credits, free_hours_count, machine_credit = _will_use_credits?
        if will_use_credits
          users_credit = user.users_credits.find_or_initialize_by(credit_id: machine_credit.id)

          if users_credit.new_record?
            users_credit.hours_used = free_hours_count
          else
            users_credit.hours_used += free_hours_count
          end
          users_credit.save!
        end
      end

      private

      def _will_use_credits?
        return false, 0 unless plan

        if machine_credit = plan.machine_credits.find_by(creditable_id: reservation.reservable_id)
          users_credit = user.users_credits.find_by(credit_id: machine_credit.id)
          already_used_hours = users_credit ? users_credit.hours_used : 0

          remaining_hours = machine_credit.hours - already_used_hours

          free_hours_count = [remaining_hours, reservation.slots.size].min

          if free_hours_count.positive?
            return true, free_hours_count, machine_credit
          else
            return false, free_hours_count, machine_credit
          end
        end
        return false, 0
      end
    end

    # same as class Machine but for Training reservation
    class Training < Reservation
      def will_use_credits?
        _will_use_credits?[0]
      end

      def update_credits
        super
        will_use_credits, training_credit = _will_use_credits?
        if will_use_credits
          user.credits << training_credit # we create a new UsersCredit object
        end
      end

      private

      def _will_use_credits?
        return false, nil unless plan

        # if there is a training_credit defined for this plan and this training
        if training_credit = plan.training_credits.find_by(creditable_id: reservation.reservable_id)
          # if user has not used all the plan credits
          if user.training_credits.where(plan: plan).count < plan.training_credit_nb
            return true, training_credit
          end
        end
        return false, nil
      end
    end

    class Event < Reservation
      def will_use_credits?
        false
      end

      def update_credits; end
    end

    class Space < Reservation
      # to known if a credit will be used in the context of the given reservation
      def will_use_credits?
        _will_use_credits?[0]
      end

      def free_hours_count
        _will_use_credits?[1]
      end

      def update_credits
        super

        will_use_credits, free_hours_count, space_credit = _will_use_credits?
        return unless will_use_credits

        users_credit = user.users_credits.find_or_initialize_by(credit_id: space_credit.id)

        if users_credit.new_record?
          users_credit.hours_used = free_hours_count
        else
          users_credit.hours_used += free_hours_count
        end
        users_credit.save!
      end

      private

      def _will_use_credits?
        return false, 0 unless plan

        if space_credit = plan.space_credits.find_by(creditable_id: reservation.reservable_id)
          users_credit = user.users_credits.find_by(credit_id: space_credit.id)
          already_used_hours = users_credit ? users_credit.hours_used : 0

          remaining_hours = space_credit.hours - already_used_hours

          free_hours_count = [remaining_hours, reservation.slots.size].min

          if free_hours_count.positive?
            return true, free_hours_count, space_credit
          else
            return false, free_hours_count, space_credit
          end
        end
        return false, 0
      end
    end
  end
end
