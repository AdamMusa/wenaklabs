json.title notification.notification_type
json.description t('.subscription_partner_PLAN_has_been_subscribed_by_USER_html',
                    {
                        PLAN: notification.attached_object.plan.base_name,
                        USER: notification.attached_object.user&.profile&.full_name || t('api.notifications.deleted_user')
                    }) # messageFormat
