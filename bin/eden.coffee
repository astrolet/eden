#!/usr/bin/env coffee

opts      = require "./options"
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
    process.stdin.resume()
    process.stdin.setEncoding("utf8")
    # TODO: extract the settings from `stdin precious[0].extra.re`,
    # and pass to both `points` and `output` functions.
    # Ideally, use `JSONStream` all the way.
    phase (points process.stdin), # output stream below
    output process.stdout, opts, {}, "\n" # see above TODO for the settings...

  else
    output process.stdout, opts
    console.log "Unknown command '#{opts.command}' has bypassed the options validator..."
    console.log "Nothing to do."
    process.exit(0)

