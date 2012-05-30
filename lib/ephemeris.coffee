Gaia    = require("lin").Gaia
which   = require("which")
_       = require("massagist")._
Massage = require("massagist").Massage
Points  = require("lin").Points
Stream  = require("stream").Stream
phase   = require("./phase")


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
      # Note: this isn't fit for rerun as `@settings` are being changed...
      if _.isString(@settings.out) and @settings.out isnt "json"
        @settings.out = ["json", @settings.out]
      # Clean-up the `@settings` for later use.
      delete @settings[key] for key in ['root', 'data', 'precious']
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
      phase (@pre ephemeris.stdout), stream

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
