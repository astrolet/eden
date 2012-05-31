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

output    = require "./output"
Ephemeris = require "../lib/ephemeris"
points    = require "../lib/points"
phase     = require "../lib/phase"


switch opts.command

  when "pre"
    ephemeris = new Ephemeris opts.merge
    ephemeris.run output process.stdout, opts, ephemeris.settings, # + trail ...
    if typeof ephemeris.settings.out is "string" then "\n" else ''
    # Massaged (Array) ephemeris.settings.out somehow get their "\n" trailing...
    # Extra newlines are not added outside of command-line context, otherwise.
    # This just does consistent output compensation.
    # process.stdout.write "\n" if typeof ephemeris.settings.out is "string"
    process.stdout.emit "end"

  when "know"
    ephemeris = new Ephemeris opts.merge, ->
      ephemeris.run output process.stdout, opts, ephemeris.settings

  when "eat"
    ephemeris = new Ephemeris opts.merge, ->
      # NOTE: whatever points need the `settings` for?
      # Take them from precious.0 (implement the precious-json "extra").
      process.stdin.resume()
      process.stdin.setEncoding("utf8")
      phase (points process.stdin, ephemeris.settings), # output stream below
      output process.stdout, opts, ephemeris.settings, "\n"

  else
    output process.stdout, opts
    console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
    console.log "Nothing to do."
    process.exit(0)

