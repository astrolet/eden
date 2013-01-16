Points  = require("archai").Points
Stream  = require("stream").Stream

# This probably belongs to Points, if necessary at all...
# It could also be more efficient. Therefore...
# TODO:
# Expect / pass a JSONStream to the Points constructor.
# Don't stringify, because phase will parse it again.

module.exports = (stream) ->
  restream = new Stream
  stream.on "data", (precious) ->
    data = JSON.parse precious
    points = new Points [], data: data
    restream.emit "data", JSON.stringify(points.toJSON()) + "\n"
  restream
