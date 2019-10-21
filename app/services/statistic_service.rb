# frozen_string_literal: true

# This will generate statistics indicators for ElasticSearch database
class StatisticService
  def generate_statistic(options = default_options)
    # remove data exists
    clean_stat(options)

    # subscription month/year list
    subscriptions_list(options).each do |s|
      Stats::Subscription.create({
        date: format_date(s.date),
        type: s.duration,
        subType: s.slug,
        stat: 1,
        ca: s.ca,
        planId: s.plan_id,
        subscriptionId: s.subscription_id,
        invoiceItemId: s.invoice_item_id,
        groupName: s.plan_group_name
      }.merge(user_info_stat(s)))
    end

    # machine list
    reservations_machine_list(options).each do |r|
      %w[booking hour].each do |type|
        stat = Stats::Machine.new({
          date: format_date(r.date),
          type: type,
          subType: r.machine_type,
          ca: r.ca,
          machineId: r.machine_id,
          name: r.machine_name,
          reservationId: r.reservation_id
        }.merge(user_info_stat(r)))
        stat.stat = (type == 'booking' ? 1 : r.nb_hours)
        stat.save
      end
    end

    # space list
    reservations_space_list(options).each do |r|
      %w[booking hour].each do |type|
        stat = Stats::Space.new({
          date: format_date(r.date),
          type: type,
          subType: r.space_type,
          ca: r.ca,
          spaceId: r.space_id,
          name: r.space_name,
          reservationId: r.reservation_id
        }.merge(user_info_stat(r)))
        stat.stat = (type == 'booking' ? 1 : r.nb_hours)
        stat.save
      end
    end

    # training list
    reservations_training_list(options).each do |r|
      %w[booking hour].each do |type|
        stat = Stats::Training.new({
          date: format_date(r.date),
          type: type,
          subType: r.training_type,
          ca: r.ca,
          trainingId: r.training_id,
          name: r.training_name,
          trainingDate: r.training_date,
          reservationId: r.reservation_id
        }.merge(user_info_stat(r)))
        stat.stat = (type == 'booking' ? 1 : r.nb_hours)
        stat.save
      end
    end

    # event list
    reservations_event_list(options).each do |r|
      %w[booking hour].each do |type|
        stat = Stats::Event.new({
          date: format_date(r.date),
          type: type,
          subType: r.event_type,
          ca: r.ca,
          eventId: r.event_id,
          name: r.event_name,
          eventDate: r.event_date,
          reservationId: r.reservation_id,
          eventTheme: r.event_theme,
          ageRange: r.age_range
        }.merge(user_info_stat(r)))
        stat.stat = (type == 'booking' ? r.nb_places : r.nb_hours)
        stat.save
      end
    end

    # account list
    members_list(options).each do |m|
      Stats::Account.create({
        date: format_date(m.date),
        type: 'member',
        subType: 'created',
        stat: 1
      }.merge(user_info_stat(m)))
    end

    # project list
    projects_list(options).each do |p|
      Stats::Project.create({
        date: format_date(p.date),
        type: 'project',
        subType: 'published',
        stat: 1
      }.merge(user_info_stat(p)).merge(project_info_stat(p)))
    end

    # member ca list
    members_ca_list(options).each do |m|
      Stats::User.create({
        date: format_date(m.date),
        type: 'revenue',
        subType: m.group,
        stat: m.ca
      }.merge(user_info_stat(m)))
    end
  end

  def subscriptions_list(options = default_options)
    result = []
    InvoiceItem.where('invoice_items.created_at >= :start_date AND invoice_items.created_at <= :end_date', options)
               .eager_load(invoice: [:coupon], subscription: [:plan, statistic_profile: [:group]]).each do |i|
      next if i.invoice.is_a?(Avoir)

      sub = i.subscription

      next unless sub

      ca = i.amount.to_i / 100.0
      cs = CouponService.new
      ca = cs.ventilate(cs.invoice_total_no_coupon(i.invoice), ca, i.invoice.coupon) unless i.invoice.coupon_id.nil?
      profile = sub.statistic_profile
      p = sub.plan
      result.push OpenStruct.new({
        date: options[:start_date].to_date,
        plan: p.group.slug,
        plan_id: p.id,
        plan_interval: p.interval,
        plan_interval_count: p.interval_count,
        plan_group_name: p.group.name,
        slug: p.slug,
        duration: p.duration.to_i,
        subscription_id: sub.id,
        invoice_item_id: i.id,
        ca: ca
      }.merge(user_info(profile)))
    end
    result
  end

  def reservations_machine_list(options = default_options)
    result = []
    Reservation
      .where("reservable_type = 'Machine' AND slots.canceled_at IS NULL AND " \
             'reservations.created_at >= :start_date AND reservations.created_at <= :end_date', options)
      .eager_load(:slots, statistic_profile: [:group], invoice: [:invoice_items])
      .each do |r|
      next unless r.reservable

      profile = r.statistic_profile
      result.push OpenStruct.new({
        date: options[:start_date].to_date,
        reservation_id: r.id,
        machine_id: r.reservable.id,
        machine_type: r.reservable.friendly_id,
        machine_name: r.reservable.name,
        nb_hours: r.slots.size,
        ca: calcul_ca(r.invoice)
      }.merge(user_info(profile)))
    end
    result
  end

  def reservations_space_list(options = default_options)
    result = []
    Reservation
      .where("reservable_type = 'Space' AND slots.canceled_at IS NULL AND " \
             'reservations.created_at >= :start_date AND reservations.created_at <= :end_date', options)
      .eager_load(:slots, statistic_profile: [:group], invoice: [:invoice_items])
      .each do |r|
      next unless r.reservable

      profile = r.statistic_profile
      result.push OpenStruct.new({
        date: options[:start_date].to_date,
        reservation_id: r.id,
        space_id: r.reservable.id,
        space_name: r.reservable.name,
        space_type: r.reservable.slug,
        nb_hours: r.slots.size,
        ca: calcul_ca(r.invoice)
      }.merge(user_info(profile)))
    end
    result
  end

  def reservations_training_list(options = default_options)
    result = []
    Reservation
      .where("reservable_type = 'Training' AND slots.canceled_at IS NULL AND " \
             'reservations.created_at >= :start_date AND reservations.created_at <= :end_date', options)
      .eager_load(:slots, statistic_profile: [:group], invoice: [:invoice_items])
      .each do |r|
      next unless r.reservable

      profile = r.statistic_profile
      slot = r.slots.first
      result.push OpenStruct.new({
        date: options[:start_date].to_date,
        reservation_id: r.id,
        training_id: r.reservable.id,
        training_type: r.reservable.friendly_id,
        training_name: r.reservable.name,
        training_date: slot.start_at.to_date,
        nb_hours: difference_in_hours(slot.start_at, slot.end_at),
        ca: calcul_ca(r.invoice)
      }.merge(user_info(profile)))
    end
    result
  end

  def reservations_event_list(options = default_options)
    result = []
    Reservation
      .where("reservable_type = 'Event' AND slots.canceled_at IS NULL AND " \
             'reservations.created_at >= :start_date AND reservations.created_at <= :end_date', options)
      .eager_load(:slots, statistic_profile: [:group], invoice: [:invoice_items])
      .each do |r|
      next unless r.reservable

      profile = r.statistic_profile
      slot = r.slots.first
      result.push OpenStruct.new({
        date: options[:start_date].to_date,
        reservation_id: r.id,
        event_id: r.reservable.id,
        event_type: r.reservable.category.slug,
        event_name: r.reservable.name,
        event_date: slot.start_at.to_date,
        event_theme: (r.reservable.event_themes.first ? r.reservable.event_themes.first.name : ''),
        age_range: (r.reservable.age_range_id ? r.reservable.age_range.name : ''),
        nb_places: r.total_booked_seats,
        nb_hours: difference_in_hours(slot.start_at, slot.end_at),
        ca: calcul_ca(r.invoice)
      }.merge(user_info(profile)))
    end
    result
  end

  def members_ca_list(options = default_options)
    subscriptions_ca_list = subscriptions_list(options)
    reservations_ca_list = []
    avoirs_ca_list = []
    result = []
    Reservation.where('reservations.created_at >= :start_date AND reservations.created_at <= :end_date', options)
               .eager_load(:slots, statistic_profile: [:group], invoice: [:invoice_items])
               .each do |r|
      next unless r.reservable

      reservations_ca_list.push OpenStruct.new({
        date: options[:start_date].to_date,
        ca: calcul_ca(r.invoice)
      }.merge(user_info(r.statistic_profile)))
    end
    Avoir.where('invoices.created_at >= :start_date AND invoices.created_at <= :end_date', options)
         .eager_load(:invoice_items, statistic_profile: [:group])
         .each do |i|
      avoirs_ca_list.push OpenStruct.new({
        date: options[:start_date].to_date,
        ca: calcul_avoir_ca(i)
      }.merge(user_info(i.statistic_profile)))
    end
    reservations_ca_list.concat(subscriptions_ca_list).concat(avoirs_ca_list).each do |e|
      profile = StatisticProfile.find(e.statistic_profile_id)
      u = find_or_create_user_info_info_list(profile, result)
      u.date = options[:start_date].to_date
      e.ca = 0 unless e.ca
      if u.ca
        u.ca = u.ca + e.ca
      else
        u.ca = 0
        u.ca = u.ca + e.ca
        result.push u
      end
    end
    result
  end

  def members_list(options = default_options)
    result = []
    member = Role.find_by(name: 'member')
    StatisticProfile.where('role_id = :member AND created_at >= :start_date AND created_at <= :end_date', options.merge(member: member.id))
                    .each do |sp|
      next if sp.user&.need_completion?

      result.push OpenStruct.new({
        date: options[:start_date].to_date
      }.merge(user_info(sp)))
    end
    result
  end

  def projects_list(options = default_options)
    result = []
    Project.where('projects.published_at >= :start_date AND projects.published_at <= :end_date', options)
           .eager_load(:licence, :themes, :components, :machines, :project_users, author: [:group])
           .each do |p|
      result.push OpenStruct.new({
        date: options[:start_date].to_date
      }.merge(user_info(p.author)).merge(project_info(p)))
    end
    result
  end

  # return always yesterday's sum of comment of each project
  # def projects_comment_nb_list
  #   result = []
  #   Project.where(state: 'published')
  #          .eager_load(:licence, :themes, :components, :machines, :project_users, author: %i[profile group])
  #          .each do |p|
  #     result.push OpenStruct.new({
  #       date: 1.day.ago.to_date,
  #       project_comments: get_project_comment_nb(p)
  #     }.merge(user_info(p.author)).merge(project_info(p)))
  #   end
  #   result
  # end

  def clean_stat(options = default_options)
    client = Elasticsearch::Model.client
    %w[Account Event Machine Project Subscription Training User Space].each do |o|
      model = "Stats::#{o}".constantize
      client.delete_by_query(
        index: model.index_name,
        type: model.document_type,
        body: { query: { match: { date: format_date(options[:start_date]) } } }
      )
    end
  end

  private

  def default_options
    yesterday = 1.day.ago
    {
      start_date: yesterday.beginning_of_day,
      end_date: yesterday.end_of_day
    }
  end

  def format_date(date)
    if date.is_a?(String)
      Date.strptime(date, '%Y%m%d').strftime('%Y-%m-%d')
    else
      date.strftime('%Y-%m-%d')
    end
  end

  def user_info(statistic_profile)
    {
      statistic_profile_id: statistic_profile.id,
      user_id: statistic_profile.user_id,
      gender: statistic_profile.str_gender,
      age: statistic_profile.age,
      group: statistic_profile.group ? statistic_profile.group.slug : nil
    }
  end

  def user_info_stat(s)
    {
      userId: s.user_id,
      gender: s.gender,
      age: s.age,
      group: s.group
    }
  end

  def calcul_ca(invoice)
    return nil unless invoice

    ca = 0
    # sum each items in the invoice (+ for invoices/- for refunds)
    invoice.invoice_items.each do |ii|
      next if ii.subscription_id

      ca = if invoice.is_a?(Avoir)
             ca - ii.amount.to_i
           else
             ca + ii.amount.to_i
           end
    end
    # subtract coupon discount from invoices and refunds
    cs = CouponService.new
    ca = cs.ventilate(cs.invoice_total_no_coupon(invoice), ca, invoice.coupon) unless invoice.coupon_id.nil?
    # divide the result by 100 to convert from centimes to monetary unit
    ca.zero? ? ca : ca / 100.0
  end

  def calcul_avoir_ca(invoice)
    ca = 0
    invoice.invoice_items.each do |ii|
      ca -= ii.amount.to_i
    end
    # subtract coupon discount from the refund
    cs = CouponService.new
    ca = cs.ventilate(cs.invoice_total_no_coupon(invoice), ca, invoice.coupon) unless invoice.coupon_id.nil?
    ca.zero? ? ca : ca / 100.0
  end

  def difference_in_hours(start_at, end_at)
    if start_at.to_date == end_at.to_date
      ((end_at - start_at) / 60 / 60).to_i
    else
      end_at_to_start_date = end_at.change(year: start_at.year, month: start_at.month, day: start_at.day)
      hours = ((end_at_to_start_date - start_at) / 60 / 60).to_i
      hours = ((end_at.to_date - start_at.to_date).to_i + 1) * hours if end_at.to_date > start_at.to_date
      hours
    end
  end

  def get_project_themes(project)
    project.themes.map do |t|
      { id: t.id, name: t.name }
    end
  end

  def get_projects_components(project)
    project.components.map do |c|
      { id: c.id, name: c.name }
    end
  end

  def get_projects_machines(project)
    project.machines.map do |m|
      { id: m.id, name: m.name }
    end
  end

  def get_project_users(project)
    sum = 0
    project.project_users.each do |pu|
      sum += 1 if pu.is_valid
    end
    sum
  end

  # def get_project_comment_nb(project)
  #   project_comment_info = @projects_comment_info.select do |p|
  #     p['identifiers'].first == "project_#{project.id}"
  #   end.first
  #   project_comment_info ? project_comment_info['posts'] : 0
  # end

  def project_info(project)
    {
      project_id: project.id,
      project_name: project.name,
      project_created_at: project.created_at,
      project_published_at: project.published_at,
      project_licence: {},
      project_themes: get_project_themes(project),
      project_components: get_projects_components(project),
      project_machines: get_projects_machines(project),
      project_users: get_project_users(project)
    }
  end

  def project_info_stat(project)
    {
      projectId: project.project_id,
      name: project.project_name,
      licence: project.project_licence,
      themes: project.project_themes,
      components: project.project_components,
      machines: project.project_machines,
      users: project.project_users
    }
  end

  # def get_user_subscription_ca(user, subscriptions_ca_list)
  #   user_subscription_ca = subscriptions_ca_list.select do |ca|
  #     ca.user_id == user.id
  #   end
  #   user_subscription_ca.inject {|sum,x| sum.ca + x.ca } || 0
  # end

  def find_or_create_user_info_info_list(profile, list)
    found = list.select do |l|
      l.statistic_profile_id == profile.id
    end.first
    found || OpenStruct.new(user_info(profile))
  end
end
