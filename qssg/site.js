// Generated by CoffeeScript 1.4.0
var Site, SiteBuilder, qcontent, qplugins, qrules, qtree, tromp;

tromp = require('tromp');

qplugins = require('./plugins');

qrules = require('./rules');

qtree = require('./tree');

qcontent = require('./content');

SiteBuilder = require('./builder').SiteBuilder;

Site = (function() {

  Object.defineProperties(Site.prototype, {
    site: {
      get: function() {
        return this;
      }
    }
  });

  function Site(opt) {
    if (opt == null) {
      opt = {};
    }
    this.meta = Object.create(opt.meta || this.meta || null);
    this._init(opt);
    this.content = qcontent.createRoot();
    this.roots = [];
  }

  Site.prototype._init = function(opt) {
    if (opt == null) {
      opt = {};
    }
    this._initWalker(opt);
    this._initMatchRuleset(opt);
    return this._initContext(opt);
  };

  Site.prototype._initWalker = function(opt) {
    if (opt == null) {
      opt = {};
    }
    this.walker = new tromp.WalkRoot({
      autoWalk: false
    });
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

  Site.prototype._initMatchRuleset = function(opt) {
    var rs;
    if (opt == null) {
      opt = {};
    }
    this.matchRuleset = rs = qrules.classifier();
    return this.initMatchRuleset(rs, qrules);
  };

  Site.prototype.initMatchRuleset = function(ruleset, qrules) {
    return qrules.standardRuleset(ruleset);
  };

  Site.prototype._initContext = function(opt) {
    this.ctx = Object.create(opt.ctx || this.ctx);
    return this.plugins = this.plugins.clone();
  };

  Site.prototype.ctx = {};

  Site.prototype.plugins = qplugins.plugins.clone();

  Site.prototype.walk = function(path, mountPath) {
    var root;
    this.roots.push(root = qtree.createRoot(this, mountPath));
    return root.walk.apply(root, arguments);
  };

  Site.prototype.build = function(rootPath, vars, done) {
    var bldr;
    vars = Object.create(vars, {
      meta: {
        value: this.meta
      }
    });
    bldr = new SiteBuilder(rootPath, this.content);
    this.done(function() {
      return bldr.build(vars, done);
    });
    return bldr;
  };

  Site.prototype.done = function(done) {
    var tid,
      _this = this;
    if (this.isDone()) {
      return done();
    }
    return tid = setInterval(function() {
      if (!_this.isDone()) {
        return;
      }
      clearInterval(tid);
      return done();
    }, 10);
  };

  Site.prototype.isDone = function() {
    if (!this.walker.isDone()) {
      return false;
    }
    return this.roots.every(function(e) {
      return e.isDone();
    });
  };

  return Site;

})();

module.exports = {
  Site: Site,
  SiteBuilder: SiteBuilder,
  createSite: function(opt) {
    return new Site(opt);
  },
  plugins: qplugins.plugins
};
