// copied from:
// https://github.com/shivercube/node-config
// https://github.com/shivercube/node-utils

var _ = require('lin')._,
    path = require('path'),
    util = require('util'),
    childProcess = require('child_process'),
    utils = {};


// Removes the first n items from the given property list
utils.shift = function(args, n) {
    return _.values(args).slice(n ? n : 1);
};

// Calls the given function with the given arguments asynchronously
utils.async = function(fn) {
    var args = utils.shift(arguments);
    setTimeout(function() { fn.apply(null, args); }, 0);
};



function init(dir, hostname, callback) {
    var conf;
    try {
        conf = require(path.join(dir, 'common')).conf;

    } catch(err) {
        callback(err);
        return;
    }

    try {
        conf = _.allFurther(conf, require(path.join(dir, hostname)).conf);

    } catch (err) {
        util.log('Could not find config file: ' + hostname);
    }

    callback(null, conf);
}

exports.init = function(dir, hostname, callback) {
    if (arguments.length == 2) { // If hostname == callback
        var hostnameProcess = childProcess.spawn('hostname');
        hostnameProcess.stdout.on('data', function(result) {
            utils.async(init, dir, _.trim(result), hostname);
        });
        hostnameProcess.stderr.on('data', hostname);

    } else utils.async(init, dir, hostname, callback);
};
