Application.Services.service('es', function (esFactory) {
  return esFactory({ host: window.location.origin });
});
