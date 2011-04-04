_       = require("lin")._
fs      = require("fs")
util    = require("util")
opts    = require("./options")
conf    = require("./node-config")
inspect = require("eyes").inspector({styles: {all: "magenta"}})
Ephemeris = require("ephemeris")

output = (ephemeris) ->
  if opts.verbose
    console.log "command: #{opts.command}"
    console.log "options:"
    inspect opts.argv
    console.log "request:"
    inspect ephemeris.directions
    console.log ""
    console.log "results"
    console.log "======="
  ephemeris.run(process.stdout)
  console.log ""

tardis = (directions) ->
  directions = _.allFurther(directions, opts.merge)
  switch opts.command
    when "ephemeris"
      if not opts.argv.data.match /^\//
        directions.data = "#{__dirname}/#{directions.root}#{opts.argv.data}" # relative paths
      ephemeris = new Ephemeris directions
      output ephemeris
    when "experiment"
      # TODO: use seq
      fs.readFile "#{__dirname}/config/ephemeris.js", "ascii", (err, data) ->
        throw err if err
        config = _.allFurther({"root": "../"}, eval data)
        config.data = "#{__dirname}/#{config.root}mnt/sin/data/" # TODO: what's the point? fix this
        ephemeris = new Ephemeris config
        ephemeris.run(process.stdout, ["json", "indent"])

    else
      console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
      console.log "Nothing to do."
      process.exit(0)

conf.init __dirname + "/config", opts.command, (error, directions) ->
  if error?
    util.print "Unable to init the config: " + error
    process.exit(1)

  tardis directions
