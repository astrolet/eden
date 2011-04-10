argv  = require("optimist").argv
_     = require("massagist")._

class Options

  commands: ["help", "ephemeris"]
  help: false
  verbose: false
  easy:
    ephemeris:
      time: "1974-06-30T23:45:00.000+02:00"
      ###
      geo:
        { "lat": 43.2166667 # "43N13"
        , "lon": 27.9166667 # "27E55"
        }
      ###
      geo: new String("43.2166667,27.9166667") # TODO: why is this not a String to begin with?

  man: (what = "help") ->
    # TODO: use ronn? markdown help files (see how npm does it)
    console.log "Help for #{what} is coming..."
    process.exit(0)

  constructor: (argv) ->
    @argv = argv

    # ephemeris is the default command (there is no empty _ array)
    if @argv._.length is 0
      @argv._ = ["ephemeris"]

    # command validation / setting
    _.each _.intersect(argv._, this.commands), (command) ->
        if command is "help"
          @help = true
        else
          @command = command # the last command wins
    , this

    # help & exit
    if @help
      this.man(@command)
    else unless @command?
      console.log "Missing or invalid command."
      this.man()

    # special options
    @verbose = true if argv.verbose or argv.v
    @merge = if argv.easy or argv.e then this.easy[@command] else {}
    # massaged output
    @merge.out = argv.o if argv.o? and not (argv.o instanceof Boolean)
    @merge.out = argv.out if argv.out? and not (argv.out instanceof Boolean) # spelled-out wins
    unless @merge.out?
      @merge.out = ["json", "inspect"] # the cli default
    else
      # NOTE: this could be simplified, but is it worth the bother?
      any_equal = if @merge.out.match /=/ then true else false
      if @merge.out.match /,/ # comma-separated sequence (= Array)
        @merge.out = @merge.out.split ","
      else if any_equal
        # "=" options without "," sequence (puts it in Array form)
        @merge.out = [@merge.out]
      if any_equal
        # if there are any options (for a single massage or several in a row)
        @merge.out = _.map @merge.out, (massagist) ->
          if massagist.match /=/
            out = massagist.split "="
            if out[1].match /^{/
              # can take json options as long as it's valid json
              # e.g. `cli -o json,inspect={\"styles\":{\"all\":\"magenta\"}}`
              try
                return [out[0], JSON.parse(out[1])]
              catch error
                console.log error
                console.log "Massagist '#{out[0]}' has invalid json option: #{out[1]}"
                process.exit(1)
            else
              # assuming string options (e.g. intent="\t") - compensating for strange \t behavior
              return [out[0], String(out[1]).replace(/\\t/g, "\t")]
          else
            return massagist

    # ephemeris data path default
    # NOTE: do we want an @argv.data default, or put it into @merge?
    @argv.data ?= "mnt/sin/data/" if @command is "ephemeris"

    # TODO: process more options (add to @merge) ...


module.exports = new Options argv
