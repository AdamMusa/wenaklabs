# frozen_string_literal: true

# AgeRange is an optional filter used to categorize Events
class AgeRange < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  has_many :events, dependent: :nullify

  def safe_destroy
    if events.count.zero?
      destroy
    else
      false
    end
  end
end
