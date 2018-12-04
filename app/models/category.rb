class Category < ActiveRecord::Base
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :events, dependent: :destroy

  after_create :create_statistic_subtype
  after_update :update_statistic_subtype, if: :name_changed?
  after_destroy :remove_statistic_subtype


  def create_statistic_subtype
    index = StatisticIndex.where(es_type_key: 'event')
    StatisticSubType.create!(statistic_types: index.first.statistic_types, key: slug, label: name)
  end

  def update_statistic_subtype
    index = StatisticIndex.where(es_type_key: 'event')
    subtype = StatisticSubType.joins(statistic_type_sub_types: :statistic_type)
                              .where(key: slug, statistic_types: { statistic_index_id: index.first.id })
                              .first
    subtype.label = name
    subtype.save!
  end

  def remove_statistic_subtype
    subtype = StatisticSubType.where(key: slug).first
    subtype.destroy!
  end

  def safe_destroy
    if Category.count > 1 && events.count.zero?
      destroy
    else
      false
    end
  end
end
