_       = require("lin")._
Gaia    = require("lin").Gaia
util    = require("util")
spawn   = require("child_process").spawn
Massage = require("lin").Massage


class Ephemeris

  # @settings.out can be:
  # "json" (is python's default)
  # "print" (python's print)
  # "pprint" (python's pretty-substitutes swe labels)
  # "inspect" (even prettier)
  # ... see Massage for more

  defaults:
    "root": "#{__dirname}/../"
    "data": "mnt/sin/data/"
    "out": "json"
    "time": null
    "geo": {"lat": null, "lon": null}
    "dms": false
    "ecliptic": [0, 3]
    "things": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 15]
    "minors": [136199, 7066, 50000, 90377, 20000, 128]
    "system": "P"

  constructor: (@specifics = {}) ->
    @settings = _.allFurther(@defaults, @specifics)

    unless @settings.data.match /^\//
      # if not absolute then relative (to eden) ephemeris data path
      @settings.data = "#{@settings.root}#{@settings.data}"

    @gaia = new Gaia @settings["geo"], @settings["time"]
    @settings.geo = {} # NOTE: overwrites the original geo - it should be an equivalent...
    @settings.geo.lat = @gaia.lat
    @settings.geo.lon = @gaia.lon
    @settings.ut = @gaia.ut


  run: (stream, treats) ->
    ephemeris = spawn "python", ["ephemeris.py", "#{JSON.stringify(@settings)}"]
                              , { cwd: __dirname + "/../bin" }
    treats = @settings.out if @settings.out instanceof Array and not treats?
    if treats?
      massage = new Massage treats
      massage.pipe ephemeris.stdout, stream, "ascii"
    else if _.include ["inspect", "indent"], @settings.out
      massage = new Massage ["json", @settings.out]
      massage.pipe ephemeris.stdout, stream, "ascii"
    else if @settings.out == "yaml"
      massage = new Massage [@settings.out]
      massage.pipe ephemeris.stdout, stream, "ascii"
    else
      util.pump ephemeris.stdout, stream, (error) ->
        throw error if error?

    ephemeris.stderr.on "data", (data) ->
      console.log data.toString("ascii")
    ephemeris.on "exit", (code) ->
      if code isnt 0
        console.log 'ephemeris exited with code ' + code;


module.exports = Ephemeris
