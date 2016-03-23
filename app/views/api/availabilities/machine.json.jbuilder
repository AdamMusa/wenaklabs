json.array!(@slots) do |slot|
  json.id slot.id if slot.id
  json.can_modify slot.can_modify
  json.title slot.title
  json.start slot.start_at.iso8601
  json.end slot.end_at.iso8601
  json.is_reserved slot.is_reserved
  json.backgroundColor 'white'
  json.borderColor slot.is_reserved ? (slot.is_reserved_by_current_user ? '#b2e774' : '#1d98ec') : '#e4cd78'

  json.availability_id slot.availability_id
  json.machine do
    json.id slot.machine.id
    json.name slot.machine.name
  end
  # the user who booked the slot ...
  json.user do
    json.id slot.reservation.user.id
    json.name slot.reservation.user.profile.full_name
  end if slot.reservation # ... if the slot was reserved
  json.tag_ids slot.availability.tag_ids
  json.tags slot.availability.tags do |t|
    json.id t.id
    json.name t.name
  end
end
