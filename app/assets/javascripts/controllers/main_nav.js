/* eslint-disable
    no-undef,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
'use strict';

/**
 * Navigation controller. List the links availables in the left navigation pane and their icon.
 */
Application.Controllers.controller('MainNavController', ['$scope', function ($scope) {
  // Common links (public application)
  $scope.navLinks = [
    {
      state: 'app.public.home',
      linkText: 'app.public.common.home',
      linkIcon: 'home',
      class: 'home-link'
    },
    { class: 'menu-spacer' },
    {
      state: 'app.public.calendar',
      linkText: 'app.public.common.public_calendar',
      linkIcon: 'calendar',
      class: 'public-calendar-link'
    },
    {
      state: 'app.public.machines_list',
      linkText: 'app.public.common.reserve_a_machine',
      linkIcon: 'cogs',
      class: 'reserve-machine-link'
    },
    {
      state: 'app.public.trainings_list',
      linkText: 'app.public.common.trainings_registrations',
      linkIcon: 'graduation-cap',
      class: 'reserve-training-link'
    },
    {
      state: 'app.public.events_list',
      linkText: 'app.public.common.events_registrations',
      linkIcon: 'tags',
      class: 'reserve-event-link'
    },
    { class: 'menu-spacer' },
    {
      state: 'app.public.projects_list',
      linkText: 'app.public.common.projects_gallery',
      linkIcon: 'th',
      class: 'projects-gallery-link'
    },
    { class: 'menu-spacer' }

  ];

  if (!Fablab.withoutPlans) {
    $scope.navLinks.push({
      state: 'app.public.plans',
      linkText: 'app.public.common.subscriptions',
      linkIcon: 'credit-card',
      class: 'plans-link'
    });
  }

  if (!Fablab.withoutSpaces) {
    $scope.navLinks.splice(4, 0, {
      state: 'app.public.spaces_list',
      linkText: 'app.public.common.reserve_a_space',
      linkIcon: 'rocket',
      class: 'reserve-space-link'
    });
  }

  Fablab.adminNavLinks = Fablab.adminNavLinks || [];
  const adminNavLinks = [
    {
      state: 'app.admin.calendar',
      linkText: 'app.public.common.manage_the_calendar',
      linkIcon: 'calendar'
    },
    {
      state: 'app.public.machines_list',
      linkText: 'app.public.common.manage_the_machines',
      linkIcon: 'cogs'
    },
    {
      state: 'app.admin.trainings',
      linkText: 'app.public.common.trainings_monitoring',
      linkIcon: 'graduation-cap'
    },
    {
      state: 'app.admin.events',
      linkText: 'app.public.common.manage_the_events',
      linkIcon: 'tags'
    },
    { class: 'menu-spacer' },
    {
      state: 'app.admin.members',
      linkText: 'app.public.common.manage_the_users',
      linkIcon: 'users'
    },
    {
      state: 'app.admin.pricing',
      linkText: 'app.public.common.subscriptions_and_prices',
      linkIcon: 'money'
    },
    {
      state: 'app.admin.invoices',
      linkText: 'app.public.common.manage_the_invoices',
      linkIcon: 'file-pdf-o'
    },
    {
      state: 'app.admin.statistics',
      linkText: 'app.public.common.statistics',
      linkIcon: 'bar-chart-o'
    },
    { class: 'menu-spacer' },
    {
      state: 'app.admin.settings',
      linkText: 'app.public.common.customization',
      linkIcon: 'gear'
    },
    {
      state: 'app.admin.project_elements',
      linkText: 'app.public.common.manage_the_projects_elements',
      linkIcon: 'tasks'
    },
    {
      state: 'app.admin.open_api_clients',
      linkText: 'app.public.common.open_api_clients',
      linkIcon: 'cloud'
    }
  ].concat(Fablab.adminNavLinks);

  $scope.adminNavLinks = adminNavLinks;

  if (!Fablab.withoutSpaces) {
    return $scope.adminNavLinks.splice(4, 0, {
      state: 'app.public.spaces_list',
      linkText: 'app.public.common.manage_the_spaces',
      linkIcon: 'rocket'
    });
  }
}
]);
