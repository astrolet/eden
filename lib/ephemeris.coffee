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
    "stuff": [ [0, 1, 2, 3]
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

    else if @settings.out is "phase"
      # TODO: add points to the treats / massage.
      # This is just points presentation,
      # and it could be done with massage as well.
      # Or later with a view.
      settings = @settings # so it can be passed to points as options
      ephemeris.stdout.on "data", (precious) ->
        points = new Points [], {data: JSON.parse(precious), settings: settings}
        json = points.toJSON()

        # It's just about output format from here on.
        if json.length > 0
          ensemble = new (require "lin").Ensemble
          longitude = "   longitude" # the name cliff label
          rpad = ' ' # right-padding for better readability
          table =
            [ { key: " "
              , req: ["id", "sid"]
              , act: true
              , val: (its, it) ->
                lead = if its.sid >= 10000 then "+" else ""
                if it.get('u')? then it.get('u').white else lead
              }
            , { key: "what"
              , req: ["id"]
              , act: true
              , val: (its, it) ->
                if it.get('id') is '?' then its.id else it.get 'name'
              }
            , { key: longitude
              , req: ["lon"]
              , act: true
              , val: (its) ->
                degrees.lon(its.lon).rep('str')
              , sort: "lon"
              }
            , { key: "~"
              , req: ["day_lon"]
              , act: true
              , val: (its) ->
                if its.day_lon < 0 then '℞'.red else ''
              }
            , { key: " speed"
              , req: ["day_lon"]
              , act: true
              , val: (its) ->
                if its.day_lon?
                  front = ('' if its.day_lon < 0 or its.day_lon >= 10) ? ' '
                  front + its.day_lon.toFixed 3
                else ''
              }
            , { key: "  latitude"
              , req: ["lat"]
              , act: false
              , val: (its) ->
                degrees.of(its.lat).str()
              }
            , { key: "distance"
              , req: ["dau"]
              , act: true
              , val: (its) ->
                return '' unless _.isNumber its.dau
                its.dau.toFixed(4 - String(Math.floor its.dau).length) + " AU"
              }
            , { key: "reason"
              , req: ["re"]
              , act: false
              , val: (its) ->
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
              out[i].order.push Number(item.lon)
              out[i]['what'] = what.green
              out[i][longitude] = mark.green
          out = _.sortBy out, (obj) -> obj['order'][0]

          # Reduce and write to the stream.
          [seq, prev] = [{}, {}]
          for i, item of out
            out[i].extra = false # innocent by default (i.e. not guilty)
            # TODO: this shoud be checking for hidden longitude degrees, instead
            if prev[longitude] isnt item[longitude]
              if _.size(seq) > 1
                # One or more of the angles can be found in this sequence.
                if (_.union ['AS', 'MC', 'DS', 'IC'], _.keys seq).length >= 1
                  for id, idx of seq
                    # Makes any house extra.
                    out[idx].extra = true if id[0] is 'H'
              seq = {} # reset the sequence
            seq["#{item.id}"] = i
            prev = item
          outer = _.filter out, (final) -> final.extra is false
          stream.write cliff.stringifyObjectRows outer, titles, color

        else stream.write "Given no data."
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
