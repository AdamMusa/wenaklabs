class SpacesAvailability < ActiveRecord::Base
  belongs_to :space
  belongs_to :availability
  after_destroy :cleanup_availability

  # when the SpacesAvailability is deleted (from Space destroy cascade), we delete the corresponding
  # availability. We don't use 'dependent: destroy' as we need to prevent conflicts if the destroy came from
  # the Availability destroy cascade.
  def cleanup_availability
    unless availability.destroying
      availability.safe_destroy
    end
  end
end
