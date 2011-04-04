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

  constructor: (@directions, moment = null, where = null) ->
    @gaia = new Gaia @directions["geo"], @directions["time"]
    @directions.geo = {} # NOTE: overwrites the original geo - it should be an equivalent...
    @directions.geo.lat = @gaia.lat
    @directions.geo.lon = @gaia.lon
    @directions.ut = @gaia.ut

module.exports = Ephemeris
