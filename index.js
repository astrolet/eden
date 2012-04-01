require("coffee-script");

// Exports
[ 'Ephemeris'
].forEach(function(name) {
  var path = './lib/' + name.toLowerCase();
  exports[name] = require(path);
});

