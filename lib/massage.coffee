_       = require("undermix")

class Massage

  stuff: null
  sequence: [] # can have several in a row
  massagist: # NOTE: pretty much all of these massagists work with json material
    json: (stuff, opt) ->
      JSON.parse stuff
    indent: (stuff, spaces = "    ") ->
      stuff = JSON.stringify stuff, null, spaces
    inspect: ( stuff
             , config = { pretty: true
                        , styles:
                          { all: "green"
                          , number: "magenta"
                          , key: "bold"
                          , string: "red"
                          }
                        , stream: null
                        , maxLength: 4096
                        }
    ) ->
      inspect = require("eyes").inspector config
      inspect stuff
    yaml: (stuff, opt) ->
      # TODO: file a bug, this doesn't parse yaml.safe_dump from http://pyyaml.org/wiki/PyYAML
      # Error: hash not properly dedented, near ": {0: 148.3199601725772, "
      # I wish this lib could do json to yaml (dump) - ask about it - then decide what does "yaml" massage mean
      # yaml is nice and compact to read ...
      require("yaml").eval(stuff)
    markdown: (stuff, opt) ->
      require("markdown").parse stuff
    codedown: (stuff, spaces) ->
      # indent (with spaces override) + each line a tab further and markdown the json as a code-block
      this.markdown ((this.indent stuff, spaces).replace /^/gm, "\t")
    validate: (stuff, opt) ->
      Schema = require("schema") # NOTE: both validate & babylon may depend on this (waiting for _ fix)
      schema = Schema.create {type:'object'}
      try
        validation = schema.validate stuff
      catch error
        console.log error
        console.log "Massage for schema.js validation has failed."
      stuff
    babylon: (stuff, language = "en") ->
      stuff

  train: (hands_on) ->
    @massagist = _.allFurther(@massagist, hands_on) if hands_on?

  study: (training) ->
    # TODO: #7853851 study training manual / helpers (get with fs)
    helpers = null
    train helpers if helpers?

  transform: (material, massagists) ->
    if material
      @stuff = material
      train massagists if massagists?

      for key in @sequence
        opt = null
        # try key with options
        if _.isArray key
          try
            # expecting [key, options]
            [key, opt] = [_.first(key), _.last(key)] # NOTE: skips _.rest (in the middle)
          catch error
            console.log error
            throw "Could not extract massagist + options from #{key}"
        # do massage with key (and options)
        if @massagist[key]?
          @stuff = @massagist[key](@stuff, opt)
        else
          console.log "Warning: Unrecognized massagist '#{key}', moving on untouched."
      @stuff + "\n"
    else
      console.log "Error: Nothing to transform. Missing massage material."

  # piping buffer transformations
  pipe: (stream_in, stream_out, encoding = "utf8") ->
    self = this
    stream_in.setEncoding encoding
    stream_in.on "data", (chunk) ->
      stream_out.end self.transform(chunk), encoding

  constructor: (@sequence = [], immediate, massagists) ->
    this.transform(immediate, massagists) if immediate?

module.exports = Massage
