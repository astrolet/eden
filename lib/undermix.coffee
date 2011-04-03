# define (require, exports, module) ->
_ =     require("underscore")
_.mixin require("underscore.string")
_.mixin

  # Converts the arguments list to an Array
  aToArr: (list) ->
    if _.isArguments(list)
      _.toArray(list).slice(0)
    else
      console.log "aToArr called with these non-arguments: #{list}"
      [list]

  # Merges all from a list of objects in return for a single one
  # sequentially overwrites keys (with disrespect for nested values)
  allFurther: (into, rest...) ->
    # _.each rest, (item) -> _.map item, (val, key) -> into[key] = val
    for item in rest
      for key, val of item
        into[key] = val
    into

module.exports = _
