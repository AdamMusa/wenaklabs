# frozen_string_literal: true

# Provides helper methods toi create an Availability with multiple occurrences
class Availabilities::CreateAvailabilitiesService
  def create(availability, occurrences)
    availability.update_attributes(occurrence_id: availability.id)

    occurrences.each do |o|
      Availability.new(
        start_at: o[:start_at],
        end_at: o[:end_at],
        available_type: availability.available_type,
        is_recurrent: availability.is_recurrent,
        period: availability.period,
        nb_periods: availability.nb_periods,
        end_date: availability.end_date,
        occurrence_id: availability.occurrence_id,
        machine_ids: availability.machine_ids,
        training_ids: availability.training_ids,
        space_ids: availability.space_ids,
        tag_ids: availability.tag_ids
      ).save!
    end
  end
end
