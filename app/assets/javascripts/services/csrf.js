'use strict';

Application.Services.service('CSRF', ['$cookies',
  function ($cookies) {
    return ({
      setMetaTags () {
        if (angular.element('meta[name="csrf-param"]').length === 0) {
          angular.element('head').append('<meta name="csrf-param" content="authenticity_token">');
          angular.element('head').append(`<meta name="csrf-token" content="${$cookies.get('XSRF-TOKEN')}">`);
        } else {
          angular.element('meta[name="csrf-token"]').replaceWith(`<meta name="csrf-token" content="${$cookies.get('XSRF-TOKEN')}">`);
        }
      }
    });
  }
]);
