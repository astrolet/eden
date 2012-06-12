_       = require("underscore")
cliff   = require("cliff")
degrees = require("upon").degrees
Ensemble = require("lin").Ensemble

# This is just points presentation,
# It could later be done with a `Backbone.View`.

module.exports = phase = (streamin, stream) ->
  streamin.on "data", (data) ->
    json = JSON.parse(data)

    # It's just about output format from here on.
    if json.length > 0
      ensemble = new Ensemble
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
      color = []
      color.push "white" for count in [0..table.length]

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

    stream.emit "end"
