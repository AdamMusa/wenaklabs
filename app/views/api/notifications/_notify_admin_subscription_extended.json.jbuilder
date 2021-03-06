json.title notification.notification_type
json.description _t('.subscription_PLAN_of_the_member_USER_has_been_extended_FREE_until_DATE_html',
                    {
                        PLAN: notification.attached_object.plan.base_name,
                        USER: notification.attached_object.user&.profile&.full_name || t('api.notifications.deleted_user'),
                        FREE: notification.get_meta_data(:free_days).to_s,
                        DATE: I18n.l(notification.attached_object.expired_at.to_date)
                    }) # messageFormat
