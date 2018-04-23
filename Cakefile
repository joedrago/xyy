browserify = require 'browserify'
coffeeify = require 'coffeeify'
uglifyify = require 'uglifyify'
nodeStatic = require 'node-static'

fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
util = require 'util'
watch = require 'node-watch'

coffeeName = 'coffee'
if process.platform == 'win32'
  coffeeName += '.cmd'

buildApp = (callback) ->
  # equal of command line $ "browserify --debug -t coffeeify ./src/main.coffee > bundle.js "
  productionBuild = (process.env.NODE_ENV == 'production')
  opts = {
    extensions: ['.coffee']
  }
  if not productionBuild
    opts.debug = true
  b = browserify opts
  b.add './src/main.coffee'
  b.transform coffeeify
  if productionBuild
    b.transform { global: true, ignore: ['**/main.*'] }, uglifyify
  b.bundle (err, result) ->
    if not err
      fs.writeFile "index.js", result, (err) ->
        if not err
          util.log "App compilation finished."
          callback?()
        else
          util.log "\x07App bundle write failed: " + err
    else
      util.log "\x07App compilation failed: " + err

buildVersion = (callback) ->
  appVersion = getVersion()
  source = """
    module.exports = "#{appVersion}"
  """
  versionFilename = "./src/version.coffee"
  sourceOnDisk = fs.readFileSync(versionFilename, "utf8")
  if source != sourceOnDisk
    fs.writeFileSync(versionFilename, source)
    util.log "Updated version to #{appVersion}"
  callback?()

buildEverything = (callback) ->
  buildVersion ->
    buildApp ->
      callback?()

getVersion = ->
  return JSON.parse(fs.readFileSync("package.json", "utf8")).version

watchEverything = ->
  util.log "Watching for changes in src"
  watch ['src','package.json'], (filename) ->
    coffeeFileRegex = /\.coffee$/
    if coffeeFileRegex.test(filename) || (filename == 'package.json')
      util.log "Source code #{filename} changed."
      util.log "Regenerating bundle..."
      buildEverything()
  buildEverything()

task 'build', 'build app', (options) ->
  buildEverything()

task 'watch', 'Run dev server and watch for changed source files to automatically rebuild', (options) ->
  watchEverything()

task 'serve', 'serve App and watch', (options) ->
  console.log "nodeStatic #{Object.keys(nodeStatic)}"
  fileServer = new nodeStatic.Server('.', { cache: 0 })
  require('http').createServer( (request, response) ->
    request.addListener('end', ->
      util.log "Serving #{request.url}"
      fileServer.serve(request, response)
    ).resume()
  ).listen(8080)
  util.log "Listening on port 8080"
  watchEverything()
