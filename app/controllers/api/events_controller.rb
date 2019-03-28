# frozen_string_literal: true

# API Controller for resources of type Event
class API::EventsController < API::ApiController
  before_action :set_event, only: %i[show update destroy]

  def index
    @events = policy_scope(Event)
    @page = params[:page]
    @scope = params[:scope]

    # filters
    @events = @events.joins(:category).where('categories.id = :category', category: params[:category_id]) if params[:category_id]
    @events = @events.joins(:event_themes).where('event_themes.id = :theme', theme: params[:theme_id]) if params[:theme_id]
    @events = @events.where('age_range_id = :age_range', age_range: params[:age_range_id]) if params[:age_range_id]

    if current_user&.admin?
      @events = case params[:scope]
                when 'future'
                  @events.where('availabilities.start_at >= ?', Time.now).order('availabilities.start_at DESC')
                when 'future_asc'
                  @events.where('availabilities.start_at >= ?', Time.now).order('availabilities.start_at ASC')
                when 'passed'
                  @events.where('availabilities.start_at < ?', Time.now).order('availabilities.start_at DESC')
                else
                  @events.order('availabilities.start_at DESC')
                end
    end

    # paginate
    @events = @events.page(@page).per(12)
  end

  # GET /events/upcoming/:limit
  def upcoming
    limit = params[:limit]
    @events = Event.includes(:event_image, :event_files, :availability, :category)
                   .where('events.nb_total_places != -1 OR events.nb_total_places IS NULL')
                   .where('availabilities.start_at >= ?', Time.now)
                   .order('availabilities.start_at ASC').references(:availabilities)
                   .limit(limit)
  end

  def show; end

  def create
    authorize Event
    @event = Event.new(event_params.permit!)
    if @event.save
      render :show, status: :created, location: @event
    else
      render json: @event.errors, status: :unprocessable_entity
    end
  end

  def update
    authorize Event
    begin
      if @event.update(event_params.permit!)
        render :show, status: :ok, location: @event
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      if e.record.class.name == 'EventPriceCategory'
        render json: { error: ["#{e.record.price_category.name}: #{t('events.error_deleting_reserved_price')}"] },
               status: :unprocessable_entity
      else
        render json: { error: [t('events.other_error')] }, status: :unprocessable_entity
      end
    end

  end

  def destroy
    authorize Event
    if @event.safe_destroy
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_event
    @event = Event.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def event_params
    # handle general properties
    event_preparams = params.required(:event).permit(:title, :description, :start_date, :start_time, :end_date, :end_time,
                                                     :amount, :nb_total_places, :availability_id, :all_day, :recurrence,
                                                     :recurrence_end_at, :category_id, :event_theme_ids, :age_range_id,
                                                     event_theme_ids: [],
                                                     event_image_attributes: [:attachment],
                                                     event_files_attributes: %i[id attachment _destroy],
                                                     event_price_categories_attributes: %i[id price_category_id amount _destroy])
    EventService.process_params(event_preparams)
  end
end
