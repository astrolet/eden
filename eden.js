require.paths.unshift(__dirname + "/node_modules");

require("coffee-script");
module.exports = require("./lib/ephemeris");
