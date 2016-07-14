class API::AvailabilitiesController < API::ApiController
  before_action :authenticate_user!
  before_action :set_availability, only: [:show, :update, :destroy, :reservations]
  respond_to :json

  ## machine availabilities are divided in multiple slots of 60 minutes
  SLOT_DURATION = 60

  def index
    authorize Availability
    start_date = ActiveSupport::TimeZone[params[:timezone]].parse(params[:start])
    end_date = ActiveSupport::TimeZone[params[:timezone]].parse(params[:end]).end_of_day
    @availabilities = Availability.includes(:machines,:tags,:trainings).where.not(available_type: 'event')
                                  .where('start_at >= ? AND end_at <= ?', start_date, end_date)
  end

  def public
    start_date = ActiveSupport::TimeZone[params[:timezone]].parse(params[:start])
    end_date = ActiveSupport::TimeZone[params[:timezone]].parse(params[:end]).end_of_day
    if in_same_day(start_date, end_date)
      @training_and_event_availabilities = Availability.includes(:tags, :trainings).where.not(available_type: 'machines')
                                    .where('start_at >= ? AND end_at <= ?', start_date, end_date)
      @machine_availabilities = Availability.includes(:tags, :machines).where(available_type: 'machines')
                                    .where('start_at >= ? AND end_at <= ?', start_date, end_date)
      @machine_slots = []
      @machine_availabilities.each do |a|
        a.machines.each do |machine|
          ((a.end_at - a.start_at)/SLOT_DURATION.minutes).to_i.times do |i|
            slot = Slot.new(start_at: a.start_at + (i*SLOT_DURATION).minutes, end_at: a.start_at + (i*SLOT_DURATION).minutes + SLOT_DURATION.minutes, availability_id: a.id, availability: a, machine: machine, title: machine.name)
            @machine_slots << slot
          end
        end
      end
      @availabilities = [].concat(@training_and_event_availabilities).concat(@machine_slots)
    else
      @availabilities = Availability.includes(:tags, :machines, :trainings, :event)
                                    .where('start_at >= ? AND end_at <= ?', start_date, end_date)
    end
  end

  def show
    authorize Availability
  end

  def create
    authorize Availability
    @availability = Availability.new(availability_params)
    if @availability.save
      render :show, status: :created, location: @availability
    else
      render json: @availability.errors, status: :unprocessable_entity
    end
  end

  def update
    authorize Availability
    if @availability.update(availability_params)
      render :show, status: :ok, location: @availability
    else
      render json: @availability.errors, status: :unprocessable_entity
    end
  end

  def destroy
    authorize Availability
    if @availability.safe_destroy
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  def machine
    if params[:member_id]
      @user = User.find(params[:member_id])
    else
      @user = current_user
    end
    @current_user_role = current_user.is_admin? ? 'admin' : 'user'
    @machine = Machine.find(params[:machine_id])
    @slots = []
    @reservations = Reservation.where('reservable_type = ? and reservable_id = ?', @machine.class.to_s, @machine.id).includes(:slots, user: [:profile]).references(:slots, :user).where('slots.start_at > ?', Time.now)
    if @user.is_admin?
      @availabilities = @machine.availabilities.includes(:tags).where("end_at > ? AND available_type = 'machines'", Time.now)
    else
      end_at = 1.month.since
      end_at = 3.months.since if is_subscription_year(@user)
      @availabilities = @machine.availabilities.includes(:tags).where("end_at > ? AND end_at < ? AND available_type = 'machines'", Time.now, end_at).where('availability_tags.tag_id' => @user.tag_ids.concat([nil]))
    end
    @availabilities.each do |a|
      ((a.end_at - a.start_at)/SLOT_DURATION.minutes).to_i.times do |i|
        if (a.start_at + (i * SLOT_DURATION).minutes) > Time.now
          slot = Slot.new(start_at: a.start_at + (i*SLOT_DURATION).minutes, end_at: a.start_at + (i*SLOT_DURATION).minutes + SLOT_DURATION.minutes, availability_id: a.id, availability: a, machine: @machine, title: '')
          slot = verify_machine_is_reserved(slot, @reservations, current_user, @current_user_role)
          @slots << slot
        end
      end
    end
  end

  def trainings
    if params[:member_id]
      @user = User.find(params[:member_id])
    else
      @user = current_user
    end
    @slots = []

    # first, we get the already-made reservations
    @reservations = @user.reservations.where("reservable_type = 'Training'")
    @reservations = @reservations.where('reservable_id = :id', id: params[:training_id].to_i) if params[:training_id].is_number?
    @reservations = @reservations.joins(:slots).where('slots.start_at > ?', Time.now)

    # what is requested?
    # 1) a single training
    if params[:training_id].is_number?
      @availabilities = Training.find(params[:training_id]).availabilities
    # 2) all trainings
    else
      @availabilities = Availability.trainings
    end

    # who made the request?
    # 1) an admin (he can see all future availabilities)
    if @user.is_admin?
      @availabilities = @availabilities.includes(:tags, :slots, trainings: [:machines]).where('availabilities.start_at > ?', Time.now)
    # 2) an user (he cannot see availabilities further than 1 (or 3) months)
    else
      end_at = 1.month.since
      end_at = 3.months.since if can_show_slot_plus_three_months(@user)
      @availabilities = @availabilities.includes(:tags, :slots, :availability_tags, trainings: [:machines]).where('availabilities.start_at > ? AND availabilities.start_at < ?', Time.now, end_at).where('availability_tags.tag_id' => @user.tag_ids.concat([nil]))
    end

    # finally, we merge the availabilities with the reservations
    @availabilities.each do |a|
      a = verify_training_is_reserved(a, @reservations)
    end
  end

  def reservations
    authorize Availability
    @reservation_slots = @availability.slots.includes(reservation: [user: [:profile]]).order('slots.start_at ASC')
  end

  private
    def set_availability
      @availability = Availability.find(params[:id])
    end

    def availability_params
      params.require(:availability).permit(:start_at, :end_at, :available_type, :machine_ids, :training_ids, :nb_total_places, machine_ids: [], training_ids: [], tag_ids: [],
                                           :machines_attributes => [:id, :_destroy])
    end

    def is_reserved(start_at, reservations)
      is_reserved = false
      reservations.each do |r|
        r.slots.each do |s|
          is_reserved = true if s.start_at == start_at
        end
      end
      is_reserved
    end

    def verify_machine_is_reserved(slot, reservations, user, user_role)
      reservations.each do |r|
        r.slots.each do |s|
          if s.start_at == slot.start_at and s.canceled_at == nil
            slot.id = s.id
            slot.is_reserved = true
            slot.title = t('availabilities.not_available')
            slot.can_modify = true if user_role === 'admin'
            slot.reservation = r
          end
          if s.start_at == slot.start_at and r.user == user and s.canceled_at == nil
            slot.title = t('availabilities.i_ve_reserved')
            slot.can_modify = true
            slot.is_reserved_by_current_user = true
          end
        end
      end
      slot
    end

    def verify_training_is_reserved(availability, reservations)
      user = current_user
      reservations.each do |r|
        r.slots.each do |s|
          if s.start_at == availability.start_at and s.canceled_at == nil and availability.trainings.first.id == r.reservable_id
            availability.slot_id = s.id
            availability.is_reserved = true
            availability.can_modify = true if r.user == user
          end
        end
      end
      availability
    end

    def can_show_slot_plus_three_months(user)
      # member must have validated at least 1 training and must have a valid yearly subscription.
      user.trainings.size > 0 and is_subscription_year(user)
    end

    def is_subscription_year(user)
      user.subscription and user.subscription.plan.interval == 'year' and user.subscription.expired_at >= Time.now
    end

    def in_same_day(start_date, end_date)
      (end_date.to_date - start_date.to_date).to_i == 1
    end
end
