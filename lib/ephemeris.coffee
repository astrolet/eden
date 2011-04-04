_       = require("lin")._
Gaia    = require("lin").Gaia
util    = require("util")
spawn   = require("child_process").spawn
Massage = require("lin").Massage


class Ephemeris

  run: (stream, treats) ->
    ephemeris = spawn "python", ["ephemeris.py", "#{JSON.stringify(@directions)}"]
                              , { cwd: __dirname + "/../scripts" }
    treats = @directions.out if @directions.out instanceof Array and not treats?
    if treats?
      massage = new Massage treats
      massage.pipe ephemeris.stdout, stream, "ascii"
    else if _.include ["inspect", "indent"], @directions.out
      massage = new Massage ["json", @directions.out]
      massage.pipe ephemeris.stdout, stream, "ascii"
    else if @directions.out == "yaml"
      massage = new Massage [@directions.out]
      massage.pipe ephemeris.stdout, stream, "ascii"
    else
      util.pump ephemeris.stdout, stream, (error) ->
        throw error if error?

    ephemeris.stderr.on "data", (data) ->
      console.log data.toString("ascii")
    ephemeris.on "exit", (code) ->
      if code isnt 0
        console.log 'ephemeris exited with code ' + code;

  constructor: (@override, moment = null, where = null) ->
    @directions =
      { "root": "#{__dirname}/../"
      , "data": "#{__dirname}/../mnt/sin/data/"
      , "out": "json" # "json" (is python's default), "print" (python's print), "pprint" (python's pretty-substitutes swe labels), "inspect" (prettier default)
      , "time": null
      , "geo": {"lat": null, "lon": null}
      , "dms": false
      , "ecliptic": [0, 3]
      , "things": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 15]
      , "minors": [136199, 7066, 50000, 90377, 20000, 128]
      , "system": "P"
      }

    if @override
      @directions = _.allFurther @directions, @override

    @gaia = new Gaia @directions["geo"], @directions["time"]
    @directions.geo = {} # NOTE: overwrites the original geo - it should be an equivalent...
    @directions.geo.lat = @gaia.lat
    @directions.geo.lon = @gaia.lon
    @directions.ut = @gaia.ut

module.exports = Ephemeris
