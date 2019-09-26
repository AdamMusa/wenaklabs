# frozen_string_literal: true

require 'file_size_validator'

# An Import is a file uploaded by an user that provides some data to the database.
# Currently, this is used to import some users from a CSV file
class Import < ActiveRecord::Base
  mount_uploader :attachment, ImportUploader

  belongs_to :user

  validates :attachment, file_size: { maximum: Rails.application.secrets.max_import_size&.to_i || 5.megabytes.to_i }
  validates :attachment, file_mime_type: { content_type: %w[text/csv text/comma-separated-values application/vnd.ms-excel] }

  after_commit :proceed_import, on: [:create]

  def results_hash
    YAML.safe_load(results, [Symbol]) if results
  end

  private

  def proceed_import
    case category
    when 'members'
      MembersImportWorker.perform_async(id)
    else
      raise NoMethodError, "Unknown import service for #{category}"
    end
  end
end
