Gaia    = require("lin").Gaia
util    = require("util")
which   = require("which")
spawn   = require("child_process").spawn
Massage = require("massagist").Massage
_       = require("massagist")._
cliff   = require("cliff")
degrees = require("upon").degrees
Points  = require("lin").Points
Stream  = require("stream").Stream


class Ephemeris

  # The defaults-overriding options will become part of
  # the help command, the man-pages / docs and the gh-pages.
  # For example the `-o` that overrides `@settings.out` can be:
  #
  # * `points` (phase is based on it)
  # * `phase` (your CLI Formatting Friend)
  # * `points,table` (raw cliff output of points)
  # * `json` (the precious json)
  # * `json,codedown` (markdown code block html)
  # * `print` (python's print)
  # * `pprint` (python's pretty-substitutes swe labels)
  # * `inspect` (the pretty eyes thing)
  # * see `Massage` for more options...

  defaults:
    "root": "#{__dirname}/../"
    "out": "json"
    "time": null
    "geo": {"lat": null, "lon": null}
    "dms": false
    "stuff": [ [0, 1, 2, 3]
             , [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 15, 17, 18, 19, 20]
             , [136199, 7066, 50000, 90377, 20000]
             ]
    "houses": "W"


  # Configure ephemeris specifics, this is valid precious input.
  configure: (specifics, cb) ->
    @specifics = specifics if specifics?
    @settings = _.allFurther @defaults, @specifics

    unless @settings.data?.match /^\//
      # If not absolute, then relative (to eden) ephemeris data path.
      @settings.data = "#{@settings.root}#{@settings.data}"

    # The @settings.ut and @settings.geo - being reset.
    @gaia = new Gaia @settings["geo"], @settings["time"]
    @settings.geo = {}
    @settings.geo.lat = @gaia.lat
    @settings.geo.lon = @gaia.lon
    @settings.ut = @gaia.ut

    # The @ephemeris is a function that implements
    # [precious json](http://astrolet.github.com/precious/json.7.html) -
    # input & output conforming to the spec.  It is optional,
    # as we may just want to use this class for generating ephemeris input -
    # the output results being deferred for later perhaps.
    # It's only set once, as it isn't expected to change.
    unless @ephemeris?
      if _.isString @settings.precious
        @ephemeris = require(@settings.precious).ephemeris

    # This can be called in various contexts.  Example: the callback can be used
    # when the ephemeris paths are not immediately known (a global precious).
    # It's passed via the `@constructor` / `@preciousPaths`
    # - see the following sections...
    cb() if cb?
    @


  # Because precious is not a dependency, nor is gravity,
  # get the paths from a global precious install.
  preciousPaths: (cb) ->
    which "precious", (er, thing) =>
      if er?
        # TODO: handle precious not installed
        console.error(er.message)
        @defaults.precious = null
      else
        apath = thing.substring 0, thing.lastIndexOf '/'
        apath += '/../lib/node_modules/precious/'
        @defaults.data = apath + 'node_modules/gravity/data/'
        @defaults.prep = apath + 'bin/'
        @defaults.precious = apath + 'index.js'
        cb()


  # Pass a callback if you need to call @run *immediately*, or something...
  constructor: (specifics = {}, cb) ->
    switch specifics.precious
      # We don't want to call precious and don't care where may be installed.
      # Nothing special to do here.  This is how we use eden to get
      # json input configuration for perhaps later calling precious with.
      when false then ;
      # Precious manually installed locally in `./node_modules`.
      # Takes one's `specifics` word for it, without checking.
      # This may be how things will be done in the future -
      # by default if precious becomes a dependency.
      when true
        apath = './node_modules/'
        @defaults.data = 'precious/node_modules/gravity/data/'
        @defaults.prep = '.bin/'
        @defaults.precious = 'precious/index.js'
        specifics.precious = undefined # so that the default takes
      # Undefined may become null.  Unknown what the paths are.
      # Expecting a global precious install.  There may be none, which is null.
      # Null is bad - because undefined implies intent to use precious.
      when undefined
        return @preciousPaths => @configure specifics, cb
      # Unless all the paths have been given as specifics, throw an error.
      # Of-course, it's assumed that the paths are valid.
      # More about completeness than intended use.
      else
        unless _.isString specifics.precious
          throw "Invalid precious specifics!"

    return @configure specifics, cb


  # A way to change just the output format, with possible method-chaining.
  out: (treats) ->
    @settings.out = treats
    @

  # Just for processing *points* output as json (at this point).
  # It also sets up the *points* json for *phase*.
  pre: (stream) ->
    process = true
    points = "points"
    becoming = "json"
    # This is so that points can be passed as JSON to `Massage` further.
    if _.isArray(@settings.out) and @settings.out[0] is points
      [process, @settings.out[0]] = [points, becoming]
    # Only the data changes for the following, `@settings.out` remains as is.
    else if _.include [points, "phase"], @settings.out
      process = points

    # Specific processing (e.g. points), or else return the same stream
    # without changing anything at all.
    if process is points
      restream = new Stream
      settings = @settings # so it can be passed to points as options
      stream.on "data", (precious) ->
        points = new Points [], {data: JSON.parse(precious), settings: settings}
        restream.emit "data", JSON.stringify(points.toJSON()) + "\n"
      restream
    else
      stream


  # This is the reason `Ephemeris` exists, though running it sometimes just gets
  # the `@settings`, so that the precious ephemeris can perhaps later be invoked
  # conveniently with - or else simply for whatever reason - besides any bugs...
  run: (stream) ->
    # However, Ephemeris can't always be `@run` nor it is necessarily desirable.
    if @settings.precious is false
      if _.isString(@settings.out) and @settings.out isnt "json"
        @settings.out = ["json", @settings.out]
      if _.isArray @settings.out
        massage = new Massage @settings.out
        massage.write   JSON.stringify(@settings), stream
      else stream.write JSON.stringify(@settings)
      return
    else unless _.isFunction @ephemeris
      throw "No ephemeris to run!"
    else
      ephemeris = @ephemeris @settings

    # An array of massage steps.  Expected to be something valid that
    # Massage can handle.  The `eden` (cli) sets up an `Array`
    # if `--out` is a comma-delimited sequence.
    if _.isArray @settings.out
      streamin = @pre ephemeris.stdout
      massage = new Massage @settings.out
      massage.pipe streamin, stream, "utf8"

    # The rest of these are special cases or else straight output of whatever
    # precious returns.

    # These are the non-array single massage steps for which json is assumed
    # being implied for a starting point.  Basically a list of valid,
    # single massage steps for a more readable json output.
    else if _.include ["inspect", "indent"], @settings.out
      massage = new Massage ["json", @settings.out]
      massage.pipe ephemeris.stdout, stream, "utf8"

    # The most readable output of `eden` and
    # the default in the context of cli usage.
    else if @settings.out is "phase"
      # This is just points presentation,
      # It could later be done with a `Backbone.View`.
      streamin = @pre ephemeris.stdout
      streamin.on "data", (data) ->
        json = JSON.parse(data)

        # It's just about output format from here on.
        if json.length > 0
          ensemble = new (require "lin").Ensemble
          longitude = "   longitude" # the name cliff label
          rpad = ' ' # right-padding for better readability
          table =
            [ { "key": " "
              , "req": ["id", "sid"]
              , "act": true
              , "val": (its, it) ->
                lead = if its.sid >= 10000 then "+" else ""
                if it.get('u')? then it.get('u').white else lead
              }
            , { "key": "what"
              , "req": ["id"]
              , "act": true
              , "val": (its, it) ->
                if it.get('id') is '?' then its.id else it.get 'name'
              }
            , { "key": longitude
              , "req": ["lon"]
              , "act": true
              , "val": (its) ->
                degrees.lon(its.lon).rep('str')
              , sort: "lon"
              }
            , { "key": "~"
              , "req": ["day_lon"]
              , "act": true
              , "val": (its) ->
                if its.day_lon < 0 then '℞'.red else ''
              }
            , { "key": " speed"
              , "req": ["day_lon"]
              , "act": true
              , "val": (its) ->
                if its.day_lon?
                  front = ('' if its.day_lon < 0 or its.day_lon >= 10) ? ' '
                  front + its.day_lon.toFixed 3
                else ''
              }
            , { "key": "  latitude"
              , "req": ["lat"]
              , "act": false
              , "val": (its) ->
                degrees.of(its.lat).str()
              }
            , { "key": "distance"
              , "req": ["dau"]
              , "act": true
              , "val": (its) ->
                return '' unless _.isNumber its.dau
                its.dau.toFixed(4 - String(Math.floor its.dau).length) + " AU"
              }
            , { "key": "reason"
              , "req": ["re"]
              , "act": true
              , "val": (its) ->
                its.re
              }
            ]

          # Reconsider what will be shown.
          show = []
          for item in table
            # Don't show inactive stuff.
            continue if item.act isnt true
            # Don't work with columns all of whose values are entirely the same.
            continue if 1 is _.size _.uniq _.pluck json, item.req[0]
            show.push item
          table = show

          # The out-values, titles and their color.
          out = []
          titles = _.pluck table, 'key'
          (color ?= []).push "white" for count in [0..table.length]

          # Add the representations for better readability.
          lon = degrees.lon 0 # just for representation symbols
          for i in [0..11]
            json.push
              marker: true
              id: lon.representations[i]
              lon: i * 30
              re: "zodiac".green

          # Process and sort.
          for i, item of json
            out.push { order: [] }
            for col in table
              it = ensemble.id item.id
              piece = col.val item, it
              piece += rpad if col.key isnt '~'
              out[i][col.key] = piece
              if col.sort? and not item.marker
                out[i].order.push Number(item[col.sort])
              out[i].id = item.id # for post-processing
            # Output markers for each representation.
            if item.marker is true
              # TODO: append `" topical % fortune"` house numbers to `what`.
              what = out[i]['what']
              mark = "#{item.lon}\u00B0"
              mark = ' ' + mark for count in [0..(5 - mark.length)]
              out[i].marker = true
              out[i].order.push Number(item.lon)
              out[i]['what'] = what.green
              out[i][longitude] = mark.green
          out = _.sortBy out, (obj) -> obj['order'][0]

          # TODO: an ugly hack - resolve this technical debt!
          # It all comes from lon 0 being 360.  Perhaps a 2nd
          # special kind of longitude should be further sub-classed?
          for idx in [(out.length-1)..0]
            if out[idx].order[0] is 360 then out[idx].order[0] = 0 else break
          # Sort again, because of the above...
          out = _.sortBy out, (obj) -> obj['order'][0]

          # Reduce and write to the stream.
          [seq, prev] = [{}, {}]
          for i, item of out
            out[i].extra = false # innocent by default (i.e. not guilty)
            # Instead of `if prev[longitude] isnt item[longitude]`.
            # Note: would be nice if we didn't hardcode `order[0]`
            # to be longitude for sure (technical debt).
            # It is used all over the place!
            if prev.order?[0] isnt item.order[0]
              if _.size(seq) > 1
                angled = topical = fortune = false
                # One or more of the angles can be found in this sequence.
                if (_.union ['AS', 'MC', 'DS', 'IC'], _.keys seq).length >= 1
                  angled = true
                for id, idx of seq
                  # Makes any house extra.
                  out[idx].extra = true if id[0] is 'H' and angled is true
                  # Topical & Fortune Houses.
                  if id[0] is 'T' or id[0] is 'F'
                    out[idx].extra = true
                    switch id[0]
                      when 'T' then topical = id.substr 1
                      when 'F' then fortune = id.substr 1
                if topical isnt false
                  out[i_mark].what += " #{topical}".white
                  if fortune isnt false
                    out[i_mark].what += " / #{fortune}".white
              # Reset the sequence after a longitude change is processed.
              seq = {}
            # From here on, there is always at least one one id in the sequence.
            seq["#{item.id}"] = i
            # It's mportant to set the marker index after processing.
            # Otherwise, sometimes the next marker steals the topics.
            i_mark = i if item.marker is true
            prev = item
          outer = _.filter out, (final) -> final.extra is false
          stream.write cliff.stringifyObjectRows outer, titles, color

        else stream.write "Given no data."
        stream.write "\n"

    # Unprocessed - straight from *precious*, whatever didn't get caught above.
    # For example `eden -o pprint`.
    # Unless @pre modifies the data (points).
    else @pre(ephemeris.stdout).pipe stream

    # Special (error) cases.
    ephemeris.stderr.on "data", (data) -> console.log data.toString("ascii")
    ephemeris.on "exit", (code) ->
      if code isnt 0 then console.log 'ephemeris exited with code ' + code;

    # Know when all the data has been got.
    # Useful for post-formatting with trailing `\n` by the cli, for example.
    ephemeris.stdout.on "end", -> stream.emit "end"


module.exports = Ephemeris
