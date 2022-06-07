const webpack = require('webpack')
module.exports = {
  publicPath: process.env.NODE_ENV === 'website' ? '/captioneditor' : '/',
  filenameHashing: false,
  configureWebpack: {
    plugins: [
      new webpack.optimize.LimitChunkCountPlugin({
        maxChunks: 1
      })
    ]
  },
  configureWebpack: config => {
    config.output.filename = 'js/avviewer.js';
  },
  chainWebpack:
    config => {
      config.optimization.delete('splitChunks'),
      config.when(process.env.NODE_ENV === 'production', plugin => {
            plugin.plugin('extract-css').tap(([options, ...args]) => [
                Object.assign({}, options, { filename: 'css/avviewer.css' }),
                ...args
            ])
        }),
        config.resolve.alias.set('videojs', 'video.js');
        config.resolve.alias.set('WaveSurfer', 'wavesurfer.js');
    }
}
