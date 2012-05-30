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

Ephemeris = require "../lib/ephemeris"
points    = require "../lib/points"
phase     = require "../lib/phase"


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
    ephemeris = new Ephemeris opts.merge
    output ephemeris.settings
    ephemeris.run process.stdout
    # Massaged (Array) ephemeris.settings.out somehow get their "\n" trailing...
    # Extra newlines are not added outside of command-line context, otherwise.
    # This just does consistent output compensation.
    process.stdout.write "\n" if typeof ephemeris.settings.out is "string"
    process.stdout.emit "end"

  when "ephemeris"
    ephemeris = new Ephemeris opts.merge, ->
      output ephemeris.settings
      ephemeris.run process.stdout

  when "eat"
    ephemeris = new Ephemeris opts.merge, ->
      # NOTE: whatever points need the `settings` for?
      # Take them from precious.0 (implement the precious-json "extra").
      process.stdin.resume()
      process.stdin.setEncoding("utf8")
      phase (points process.stdin, ephemeris.settings), process.stdout

  else
    console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
    console.log "Nothing to do."
    process.exit(0)

