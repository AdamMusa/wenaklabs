# frozen_string_literal: true

# CAO file attached to a project documentation
class ProjectCao < Asset
  mount_uploader :attachment, ProjectCaoUploader

  validates :attachment, file_size: { maximum: Rails.application.secrets.max_cao_size&.to_i || 5.megabytes.to_i }
  validates :attachment, file_mime_type: { content_type: ENV['ALLOWED_MIME_TYPES'].split(' ') }
end
