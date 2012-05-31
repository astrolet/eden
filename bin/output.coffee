module.exports = (stream, opts, settings, trail) ->

  # Obviously, we don't want to spoil the json with unparseable verbosity.
  if opts.verbose and settings?.out isnt "json"
    console.log "\noptions:"
    inspect opts.argv
    console.log "command: #{opts.command}"
    if settings?
      console.log "context:"
      inspect settings
    console.log ""
    console.log "RESULTS"
    console.log "======="

  stream.write "\n"

  # The output that matters will be written here, before the end.

  stream.on "end", ->
    stream.write "\n"
    stream.write trail if trail?

  stream
