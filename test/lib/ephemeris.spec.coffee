Ephemeris = require('../../index').Ephemeris
assert    = require("chai").assert
should    = require("chai").should()


describe "Ephemeris", ->

  describe "instantiating without options", ->

    it "yields an empty object", ->
      (new Ephemeris).should.eql {}

