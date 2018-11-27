'use strict';

// list the social networks supported in the user's profiles
Application.Services.factory('SocialNetworks', [function () {
  return ['facebook', 'twitter', 'google_plus', 'viadeo', 'linkedin', 'instagram', 'youtube', 'vimeo', 'dailymotion', 'github', 'echosciences', 'website', 'pinterest', 'lastfm', 'flickr'];
}]);
