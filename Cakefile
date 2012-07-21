fs   = require 'fs'
json = require 'jsonify'
_    = require 'underscore'

test = "#{__dirname}/test"
docs = "#{__dirname}/docs"

{basename, join} = require 'path'
{exec, spawn} = require 'child_process'
{series, parallel} = require 'async'
inspect = require('eyes').inspector
  stream: null
  pretty: false
  styles:
    all: 'magenta'


# Utility functions

pleaseWait = ->
  console.log "\nThis may take a while...\n"

handleError = (err) ->
  if err
    console.log "\nUnexpected error!\nHave you done `cake install`?\n"
    console.log err.stack

# execute some command quietly (without stdout)
sh = (command) -> (k) -> exec command, k

# Modified from https://gist.github.com/920698
runCommand = (name, args) ->
    proc = spawn name, args
    proc.stderr.on 'data', (buffer) -> console.log buffer.toString()
    proc.stdout.on 'data', (buffer) -> console.log buffer.toString()
    proc.on 'exit', (status) -> process.exit(1) if status != 0

# shorthand to runCommand with
command = (c, cb) ->
  runCommand "sh", ["-c", c]
  cb


# First-time setup.  Pygments is required by docco.
# Also installs precious, so don't run it if unwanted.
# Note: this will be a local install - of precious,
# after it's coupled with nconf / args setting.
task 'install', "does: npm packages + precious, pycco, bundler / gems, etc.", ->
  pleaseWait()
  command "
    npm install
     && npm install -g precious
     && gem install bundler
     && bundle install
     && easy_install Pygments
    "


# Check if any node_modules or gems have become outdated.
task 'outdated', "is all up-to-date?", ->
  pleaseWait()
  parallel [
    command "npm outdated"
    command "bundle outdated"
  ], (err) -> throw err if err


# Usually follows `cake outdated`.
task 'update', "latest node modules & ruby gems - the lazy way", ->
  pleaseWait()
  parallel [
    command "npm update"
    command "bundle update"
  ], (err) -> throw err if err


# It's the local police at the project's root.
# Catches outdated modules that `cake outdated` doesn't report (major versions).
task 'police', "checks npm package & dependencies with `police -l .`", ->
  command "police -l ."


# Task options (for testing).
option '-b', '--bcat', "\t pipe via `bcat` to the browser as if it's the console"
option '-s', '--silent', "\t the tests are pretty quiet"
option '-v', '--verbose', "\t verbose `cake test` option, pre-configured per test framework"
option '-t', '--tests [TESTS]', "\t comma-delimited tests list: framework or path/ or path/part"

# Run all the tests.
task 'test', "multi-framework tests", (options) ->
  # test frameworks configuration
  # constraint: everything in a path is run by a single unique framework
  frameworks = json.parse fs.readFileSync "#{test}/frameworks.json", 'utf8'

  # build reverse index of framework lookup by path
  paths = {}
  for runner, config of frameworks
    for path in config.paths
      paths[path] = runner

  # option defaults
  options.neutral = true unless options.verbose or options.silent

  # -t framework(s) or paths(s) override
  tfp = options.tests
  tfp = if tfp? then tfp.split(',') else _.keys frameworks

  for fp in tfp
    if fp.indexOf('/') is -1 # doesn't end in / (valid framework expectation)
      runner = fp
      unless frameworks[runner]?
        console.log "Invalid '#{runner}' test framework."
        continue # still run whatever else
      config = frameworks[runner]
      args = _.map config.paths, (path) -> "test/#{path}/*#{config.extension}"
    else # it contains a path, verify it's valid & configure
      path = fp.split('/')[0]
      unless paths[path]?
        console.log "Invalid test path: #{path}/."
        continue # still run whatever else
      runner = paths[path]
      config = frameworks[runner]
      args = ["test/#{fp}*#{config.extension}"]
    for option in ["silent", "neutral", "verbose"]
      args.unshift config.alias[option] if options[option]?

    # TODO: these should probably be combined - so there is one `| bcat` output.
    execute = "NODE_ENV=#{options.env} ./node_modules/.bin/#{runner} #{args.join ' '}"
    execute += " | bcat" if options.bcat?
    command execute


# Literate programming for the coffee sources.
task 'docs', "docco -- docs", ->
  series [
    sh "rm -rf #{docs}/"
    command "find lib | grep .coffee | xargs docco"
  ], (err) -> throw err if err


# Build manuals / gh-pages almost exactly like https://github.com/josh/nack does

task 'man', "Build manuals", ->
  fs.readdir "doc/", (err, files) ->
    for file in files when /\.md/.test file
      source = join "doc", file
      target = join "man", basename source, ".md"
      exec "ronn --pipe --roff #{source} > #{target}", (err) ->
        throw err if err


task 'pages', "Build pages", ->

  buildMan = (callback) ->
    series [
      (sh "cp README.md doc/index.md")
      (sh 'echo "# UNLICENSE\n## LICENSE\n\n" > doc/UNLICENSE.md' )
      (sh "cat UNLICENSE >> doc/UNLICENSE.md")
      (sh "ronn -stoc -5 doc/*.md")
      (sh "mv doc/*.html pages/")
      (sh "cp -r doc/images pages/")
      (sh "rm doc/index.md")
      (sh "rm doc/UNLICENSE.md")
    ], callback

  build = (callback) ->
    parallel [
      buildMan
      (sh "cake docs && cp -r docs pages/annotations")
      ], callback

  series [
    (sh "if [ ! -d pages ] ; then mkdir pages ; fi") # mkdir pages only if it doesn't exist
    (sh "rm -rf pages/*")
    build
  ], (err) -> throw err if err


task 'pages:publish', "Publish pages", ->

  checkoutBranch = (callback) ->
    series [
      (sh "rm -rf pages/")
      (sh "git clone -q -b gh-pages git@github.com:astrolet/eden.git pages")
      (sh "rm -rf pages/*")
    ], callback

  publish = (callback) ->
    series [
      (sh "cd pages/ && git add . && git commit -m 'rebuild manual' || true")
      (sh "cd pages/ && git push git@github.com:astrolet/eden.git gh-pages")
      (sh "rm -rf pages/")
    ], callback

  series [
    checkoutBranch
    (sh "cake pages") # NOTE: (invoke "pages") # doesn't work here after checkoutBranch
    publish
  ], (err) -> throw err if err
