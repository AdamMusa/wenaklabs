class ExportPolicy < Struct.new(:user, :export)
  %w(export_reservations export_members export_subscriptions export_availabilities download status).each do |action|
    define_method "#{action}?" do
      user.is_admin?
    end
  end
end
