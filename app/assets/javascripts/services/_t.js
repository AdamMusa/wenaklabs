/* eslint-disable
    no-undef,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
'use strict';

Application.Services.factory('_t', ['$filter', $filter =>
  function (key, interpolation, options) {
    if (interpolation == null) { interpolation = undefined; }
    if (options == null) { options = undefined; }
    return $filter('translate')(key, interpolation, options);
  }

]);
