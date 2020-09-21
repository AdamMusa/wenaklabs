const { environment } = require('@rails/webpacker');
const htmlErb = require('./loaders/html_erb');
const jsErb = require('./loaders/js_erb');
const sass = require('./loaders/sass');
const sassErb = require('./loaders/sass_erb');
const html = require('./loaders/html');
const fonts = require('./loaders/fonts');
const webpack = require('webpack');
const path = require('path');

environment.plugins.prepend('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery',
  'window.jQuery': 'jquery',
  Hone: 'hone',
  Tether: 'tether',
  Application: [path.resolve(path.join(__dirname, '../../app/frontend/src/javascript/app.js')), 'Application']
}));

environment.loaders.prepend('js-erb', jsErb);
environment.loaders.prepend('html-erb', htmlErb);
environment.loaders.prepend('sass-erb', sassErb);
environment.loaders.append('html', html);
environment.loaders.append('sass', sass);
environment.loaders.append('fonts', fonts);

environment.splitChunks();

module.exports = environment;
