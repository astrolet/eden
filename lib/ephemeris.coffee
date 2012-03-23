Gaia    = require("lin").Gaia
util    = require("util")
spawn   = require("child_process").spawn
Massage = require("massagist").Massage
_       = require("massagist")._
cliff   = require("cliff")
degrees = require("lin").degrees
Points  = require("lin").Points


class Ephemeris

  # @settings.out can be:
  # * phase (Your CLI Formatting Friend)
  # * json (is python's default)
  # * print (python's print)
  # * pprint (python's pretty-substitutes swe labels)
  # * inspect (even prettier)
  # * see Massage for more...
  # These will become part of the help command / man and the gh-pages.

  defaults:
    "root": "#{__dirname}/../"
    "data": "node_modules/precious/node_modules/gravity/data/"
    "out": "json"
    "time": null
    "geo": {"lat": null, "lon": null}
    "dms": false
    "stuff": [ [0, 1, 3]
             , [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 15, 17, 18, 19, 20]
             , [136199, 7066, 50000, 90377, 20000]
             ]
    "houses": "O"

  constructor: (@specifics = {}) ->
    @settings = _.allFurther(@defaults, @specifics)

    unless @settings.data.match /^\//
      # if not absolute then relative (to eden) ephemeris data path
      @settings.data = "#{@settings.root}#{@settings.data}"

    # The @settings.ut and @settings.geo - being reset.
    @gaia = new Gaia @settings["geo"], @settings["time"]
    @settings.geo = {}
    @settings.geo.lat = @gaia.lat
    @settings.geo.lon = @gaia.lon
    @settings.ut = @gaia.ut


  run: (stream, treats) ->
    ephemeris = spawn "python", ["ephemeris.py", "#{JSON.stringify(@settings)}"]
                              , { cwd: __dirname + "/../node_modules/precious/lib" }
    treats = @settings.out if @settings.out instanceof Array and not treats?
    if treats?
      massage = new Massage treats
      massage.pipe ephemeris.stdout, stream, "ascii"
    else if @settings.out is "points"
      # NOTE: temporarily here for deveopment of precious points import.
      # This needs to be part of treats / massage as it's a json data collection.
      # Futhermore: this is just about data, not presentation.
      # The presentation code will be moved to the new "phase".
      settings = @settings # so it can be passed to points as options
      ephemeris.stdout.on "data", (precious) ->
        points = new Points [], {data: JSON.parse(precious), settings: settings}
        json = points.toJSON()
        if json.length > 0
          (colors ?= []).push "white" for count in [0.._.size(json[0])]
          stream.write cliff.stringifyObjectRows json, _.keys(json[0]), colors
        else stream.write "Given no data."
        stream.write "\n\n"
    else if @settings.out is "phase"
      # this is a bit ugly because it's easier to not change the precious output
      # will need to at least add an input method to lin's itemerge (soon)
      ensemble = new (require "lin").Ensemble
      ephemeris.stdout.on "data", (data) ->
        rpad = ' ' # pad on the right of each column (the values)
        labels =
          "0": "   longitude"
          "3": " speed"
        json = JSON.parse data
        idx = 0
        [objs, rows, colors] = [[], [" ", "what"], []]
        for i, group of json
          if i is "1" or i is "2"
            for id, it of group
              sid = if i is "2" then "#{10000 + new Number(id)}" else id
              item = ensemble.sid sid
              [lead, what] = [(if i is "2" then "+" else ""), id]
              if item.get('id') isnt '?'
                lead = item.get('u').white if item.get('u')?
                what = item.get('name')
              objs.push
                " ": lead + rpad
                "what": what + rpad
              for key, val of it
                if key is '0' or key is '3' # process just the longitude / speed
                  label = labels[key] ? key
                  switch key
                    when "0"
                      objs[idx][label] = degrees.lon(val).rep('str') + rpad
                    when "3"
                      rows.push '~' if idx is 0
                      objs[idx]['~'] = if val < 0 then '℞'.red else ''
                      # precision, rounding and alignment (if negative not <= -10?)
                      val = val.toFixed 3
                      val = (if val < 0 or val >=10  then val else " " + val)
                      objs[idx][label] = val + rpad
                    else objs[idx][label] = val + rpad
                  rows.push labels[key] if idx is 0
              idx++
        objs = _.sortBy objs, (obj) -> obj[labels['0']] # longitude-sorted
        colors.push "white" for row in rows
        stream.write cliff.stringifyObjectRows objs, rows, colors
        stream.write "\n\n"
    else if _.include ["inspect", "indent"], @settings.out
      massage = new Massage ["json", @settings.out]
      massage.pipe ephemeris.stdout, stream, "ascii"
    else
      ephemeris.stdout.pipe stream

    ephemeris.stderr.on "data", (data) ->
      console.log data.toString("ascii")
    ephemeris.on "exit", (code) ->
      if code isnt 0
        console.log 'ephemeris exited with code ' + code;


module.exports = Ephemeris
