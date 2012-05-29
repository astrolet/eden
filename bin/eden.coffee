#!/usr/bin/env coffee

opts    = require("../lib/options")
inspect = require("eyes").inspector(
                        { pretty: true
                        , styles:
                          { all: "green"
                          , number: "magenta"
                          , key: "bold"
                          , string: "blue"
                          }
                        })


output = (context) ->
  if opts.verbose
    console.log "\noptions:"
    inspect opts.argv
    console.log "command: #{opts.command}"
    if context?
      console.log "context:"
      inspect ephemeris.settings
    console.log ""
    console.log "RESULTS"
    console.log "======="
  console.log ""

process.stdout.on "end", ->
  process.stdout.write "\n"


switch opts.command

  when "pre"
    ephemeris = new (require "../lib/ephemeris")(opts.merge)
    output ephemeris.settings
    ephemeris.run process.stdout
    # Massaged (Array) ephemeris.settings.out somehow get their "\n" trailing...
    # Extra newlines are not added outside of command-line context, otherwise.
    # This just does consistent output compensation.
    process.stdout.write "\n" if typeof ephemeris.settings.out is "string"
    process.stdout.emit "end"

  when "ephemeris"
    Ephemeris = require("../lib/ephemeris")
    ephemeris = new Ephemeris opts.merge, ->
      output ephemeris.settings
      ephemeris.run process.stdout

  else
    console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
    console.log "Nothing to do."
    process.exit(0)

