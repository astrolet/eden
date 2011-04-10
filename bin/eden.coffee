#!/usr/bin/env coffee

require.paths.unshift __dirname + "/../lib"
require.paths.unshift __dirname + "/../node_modules"

opts    = require("options")
inspect = require("eyes").inspector({styles: {all: "magenta"}})
_       = require("massagist")._
Ephemeris = require("ephemeris")

output = (ephemeris, massage) ->
  if opts.verbose
    console.log "command: #{opts.command}"
    console.log "options:"
    inspect opts.argv
    console.log "request:"
    inspect ephemeris.directions
    console.log ""
    console.log "results"
    console.log "======="
  ephemeris.run(process.stdout, massage)
  console.log ""

switch opts.command
  when "ephemeris"
    ephemeris = new Ephemeris opts.merge
    output ephemeris

  else
    console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
    console.log "Nothing to do."
    process.exit(0)
