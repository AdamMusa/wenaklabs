# frozen_string_literal: true

# Project is the documentation about an object built by a fab-user
# It can describe the steps taken by the fab-user to build his object, provide photos, description, attached CAO files, etc.
class Project < ActiveRecord::Base
  include AASM
  include NotifyWith::NotificationAttachedObject
  include OpenlabSync

  # elastic initialisations
  include Elasticsearch::Model
  index_name 'fablab'
  document_type 'projects'

  # kaminari
  # -- dependency in app/assets/javascripts/controllers/projects.js.erb
  paginates_per 16

  # friendlyId
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_one :project_image, as: :viewable, dependent: :destroy
  accepts_nested_attributes_for :project_image, allow_destroy: true
  has_many :project_caos, as: :viewable, dependent: :destroy
  accepts_nested_attributes_for :project_caos, allow_destroy: true, reject_if: :all_blank

  has_and_belongs_to_many :machines, join_table: 'projects_machines'
  has_and_belongs_to_many :spaces, join_table: 'projects_spaces'
  has_and_belongs_to_many :components, join_table: 'projects_components'
  has_and_belongs_to_many :themes, join_table: 'projects_themes'

  has_many :project_users, dependent: :destroy
  has_many :users, through: :project_users

  belongs_to :author, foreign_key: :author_statistic_profile_id, class_name: 'StatisticProfile'
  belongs_to :licence, foreign_key: :licence_id

  has_many :project_steps, dependent: :destroy
  accepts_nested_attributes_for :project_steps, allow_destroy: true

  # validations
  validates :author, :name, presence: true

  after_save :after_save_and_publish

  aasm column: 'state' do
    state :draft, initial: true
    state :published

    event :publish, after: :notify_admin_when_project_published do
      transitions from: :draft, to: :published
    end
  end

  # scopes
  scope :published, -> { where("state = 'published'") }

  ## elastic
  # callbacks
  after_save { ProjectIndexerWorker.perform_async(:index, id) }
  after_destroy { ProjectIndexerWorker.perform_async(:delete, id) }

  # mapping
  settings index: { number_of_replicas: 0 } do
    mappings dynamic: 'true' do
      indexes 'state', analyzer: 'simple'
      indexes 'tags', analyzer: Rails.application.secrets.elasticsearch_language_analyzer
      indexes 'name', analyzer: Rails.application.secrets.elasticsearch_language_analyzer
      indexes 'description', analyzer: Rails.application.secrets.elasticsearch_language_analyzer
      indexes 'project_steps' do
        indexes 'title', analyzer: Rails.application.secrets.elasticsearch_language_analyzer
        indexes 'description', analyzer: Rails.application.secrets.elasticsearch_language_analyzer
      end
    end
  end

  # the resulting JSON will be indexed in ElasticSearch, as /fablab/projects
  def as_indexed_json
    ApplicationController.new.view_context.render(
      partial: 'api/projects/indexed',
      locals: { project: self },
      formats: [:json],
      handlers: [:jbuilder]
    )
  end

  def self.search(params, current_user)
    Project.__elasticsearch__.search(build_search_query_from_context(params, current_user))
  end

  def self.build_search_query_from_context(params, current_user)
    search = {
      query: {
        bool: {
          must: [],
          should: [],
          filter: []
        }
      }
    }

    # we sort by created_at if there isn't a query
    if params['q'].blank?
      search[:sort] = { created_at: { order: :desc } }
    else
      # otherwise we search for the word (q) in various fields
      search[:query][:bool][:must] << {
        multi_match: {
          query: params['q'],
          type: 'most_fields',
          fields: %w[tags^4 name^5 description^3 project_steps.title^2 project_steps.description]
        }
      }
    end

    # we filter by themes, components, machines
    params.each do |name, value|
      if name =~ /(.+_id$)/
        search[:query][:bool][:filter] << { term: { "#{name}s" => value } } if value
      end
    end

    # if use select filter 'my project' or 'my collaborations'
    if current_user && params.key?('from')
      search[:query][:bool][:filter] << { term: { author_id: current_user.id } } if params['from'] == 'mine'
      search[:query][:bool][:filter] << { term: { user_ids: current_user.id } } if params['from'] == 'collaboration'
    end

    # if user is connected, also display his draft projects
    if current_user
      search[:query][:bool][:should] << { term: { state: 'published' } }
      search[:query][:bool][:should] << { term: { author_id: current_user.id } }
      search[:query][:bool][:should] << { term: { user_ids: current_user.id } }
    else
      # otherwise display only published projects
      search[:query][:bool][:must] << { term: { state: 'published' } }
    end

    search
  end

  private

  def notify_admin_when_project_published
    NotificationCenter.call type: 'notify_admin_when_project_published',
                            receiver: User.admins,
                            attached_object: self
  end

  def after_save_and_publish
    return unless state_changed? && published?

    update_columns(published_at: Time.now)
    notify_admin_when_project_published
  end
end
