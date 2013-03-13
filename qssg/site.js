// Generated by CoffeeScript 1.6.1
var Site, path, qbuilder, qcontent, qentry, qplugins, qrules, qutil;

path = require('path');

qplugins = require('./plugins');

qrules = require('./rules');

qcontent = require('./content');

qentry = require('./entry');

qbuilder = require('./builder');

qutil = require('./util');

Site = (function() {

  Object.defineProperties(Site.prototype, {
    site: {
      get: function() {
        return this;
      }
    }
  });

  function Site(opt, plugins) {
    if (opt == null) {
      opt = {};
    }
    this.meta = Object.create(opt.meta || this.meta || null);
    this.ctx = Object.create(opt.ctx || null);
    this.content = qcontent.createRoot();
    this.buildTasks = qutil.invokeList.ordered();
    this._initPlugins(opt, plugins);
    this._initWalker(opt);
  }

  Site.prototype._initWalker = function(opt) {
    var ruleset;
    if (opt == null) {
      opt = {};
    }
    ruleset = qrules.classifier();
    this.initMatchRuleset(ruleset, qrules);
    this.walker = qentry.createWalker(this, ruleset);
    this.walker.reject(opt.reject || /node_modules/);
    if (opt.accept != null) {
      this.walker.accept(opt.accept);
    }
    if (opt.filter != null) {
      this.walker.filter(opt.filter);
    }
    this.initWalker(this.walker);
    return this;
  };

  Site.prototype.initWalker = function(walker) {};

  Site.prototype.initMatchRuleset = function(ruleset, qrules) {
    return qrules.standardRuleset(ruleset);
  };

  Site.prototype.plugins = qplugins.plugins.clone();

  Site.prototype._initPlugins = function(opt, plugins) {
    this.plugins = this.plugins.clone();
    if (opt.plugins != null) {
      this.plugins.merge(opt.plugins);
    }
    if (plugins != null) {
      return this.plugins.merge(plugins);
    }
  };

  Site.prototype.walk = function(aPath, opt) {
    var plugins, tree;
    if (opt == null) {
      opt = {};
    }
    if (opt.plugins != null) {
      plugins = this.plugins.clone();
      plugins.merge(opt.plugins);
    } else {
      plugins = this.plugins;
    }
    tree = this.content.addTree(path.join('.', opt.mount));
    return this.walker.walkRootContent(aPath, tree, plugins);
  };

  Site.prototype.matchEntryPlugin = function(entry, pluginFn) {
    var _this = this;
    return process.nextTick(function() {
      try {
        return pluginFn(_this.buildTasks);
      } catch (err) {
        console.warn(entry);
        console.warn(err.stack || err);
        return console.warn('');
      }
    });
  };

  Site.prototype.invokeBuildTasks = function() {
    var fn, taskFn, tasks, _i, _len, _ref;
    tasks = qutil.createTaskTracker.apply(qutil, arguments);
    _ref = this.buildTasks.sort().slice();
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      fn = _ref[_i];
      taskFn = tasks();
      try {
        fn(vars, taskFn);
      } catch (err) {
        taskFn(err);
      }
    }
    return tasks.seed();
  };

  Site.prototype.build = function(rootPath, vars, callback) {
    var bldr,
      _this = this;
    if (typeof vars === 'function') {
      callback = vars;
      vars = null;
    }
    vars = Object.create(vars || null, {
      meta: {
        value: this.meta
      }
    });
    bldr = qbuilder.createBuilder(rootPath, this.content);
    this.walker.done(qutil.debounce(100, function() {
      return _this.invokeBuildTasks(function(err, tasks) {
        return bldr.build(vars, callback);
      });
    }));
    return bldr;
  };

  return Site;

})();

module.exports = {
  Site: Site,
  createSite: function(opt, plugins) {
    return new Site(opt, plugins);
  },
  plugins: qplugins.plugins,
  createPluginMap: qplugins.createPluginMap
};
