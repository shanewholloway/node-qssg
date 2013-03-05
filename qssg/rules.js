// Generated by CoffeeScript 1.4.0
var Classifier, MatchEntry, events, path, qrules,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

path = require('path');

events = require('events');

MatchEntry = require('./entry').MatchEntry;

Classifier = (function(_super) {

  __extends(Classifier, _super);

  function Classifier() {
    this.matchRules = __bind(this.matchRules, this);
    Classifier.__super__.constructor.apply(this, arguments);
    this.rulesets = [];
    this._coreRules = this.addRuleset(0, 'core');
  }

  Classifier.prototype.asEntry = function(srcEntry) {
    return new MatchEntry(srcEntry);
  };

  Classifier.prototype.matchRules = function(walkEntry, mx) {
    var entry, fn, rules, _i, _j, _len, _len1, _ref;
    if (!(typeof mx.match === 'function')) {
      throw new Error("Classifier `mx` must implement `match()`");
    }
    entry = this.asEntry(walkEntry);
    _ref = this.rulesets;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      rules = _ref[_i];
      for (_j = 0, _len1 = rules.length; _j < _len1; _j++) {
        fn = rules[_j];
        if (fn(Object.create(entry), mx)) {
          return true;
        }
      }
    }
    return false;
  };

  Classifier.prototype.addRuleset = function(w_or_ruleset, rulesetName) {
    var idx, rs, rs0, w0, _i, _len, _ref;
    if (rulesetName != null) {
      rs0 = this.rulesets[rulesetName];
      rs0 || (rs0 = qrules.ruleset(this, w_or_ruleset));
      this.rulesets[rulesetName] = rs0;
    } else {
      rs0 = qrules.ruleset(this, w_or_ruleset);
    }
    w0 = rs0.w || 0;
    _ref = this.rulesets;
    for (idx = _i = 0, _len = _ref.length; _i < _len; idx = ++_i) {
      rs = _ref[idx];
      if (w0 < (rs.w || 0)) {
        this.rulesets.splice(idx, 0, rs0);
        return rs0;
      }
    }
    this.rulesets.push(rs0);
    return rs0;
  };

  Classifier.prototype.rule = function() {
    var fnList;
    fnList = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return this._coreRules.ruleEx(fnList);
  };

  Classifier.prototype.ruleEx = function(fnList) {
    return this._coreRules.ruleEx(fnList);
  };

  return Classifier;

})(events.EventEmitter);

qrules = {
  Classifier: Classifier,
  classifier: function(sendFn) {
    return new this.Classifier(sendFn);
  },
  anyEx: function(fnList) {
    if (typeof fnList === 'function') {
      return fnList;
    }
    if (fnList.length === 1) {
      return fnList[0];
    }
    return function(e, mx) {
      return fnList.some(function(fn) {
        return fn(e, mx);
      });
    };
  },
  any: function() {
    var fnList;
    fnList = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return qrules.anyEx(fnList);
  },
  everyEx: function(fnList) {
    if (typeof fnList === 'function') {
      return fnList;
    }
    if (fnList.length === 1) {
      return fnList[0];
    }
    return function(e, mx) {
      return fnList.every(function(fn) {
        return fn(e, mx);
      });
    };
  },
  every: function() {
    var fnList;
    fnList = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return qrules.everyEx(fnList);
  },
  ruleset: function(self, w) {
    var rs;
    rs = [];
    if (w != null) {
      rs.w = w;
    }
    rs.addRuleset = function() {
      return this;
    };
    rs.rule = function() {
      var fnList;
      fnList = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return rs.ruleEx(fnList);
    };
    rs.ruleEx = function(fnList) {
      var fn;
      fn = qrules.everyEx(fnList);
      if (fn != null) {
        rs.push(fn);
      }
      return self;
    };
    return rs;
  },
  classify: function(rx, fields, test) {
    rx = rx.source || rx;
    rx = new RegExp("^" + rx + "$", 'i');
    if (fields.split != null) {
      fields = fields.split(' ');
    }
    return function(entry) {
      var cx, mx, name0;
      name0 = entry.name0 || entry.name.split('.')[0];
      mx = rx.exec(name0);
      if (mx != null) {
        entry.cx = cx = entry.cx || {};
        fields.forEach(function(k, i) {
          var f;
          if ((f = mx[1 + i]) != null) {
            return entry[k] = cx[k] = f;
          }
        });
        if (!(test != null) || test.apply(null, arguments)) {
          return true;
        }
      }
      return false;
    };
  },
  thenMatch: function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return qrules.thenMatchEx(args);
  },
  thenMatchEx: function(args) {
    return function(entry, mx) {
      mx.match.apply(mx, [entry].concat(__slice.call(args)));
      return true;
    };
  },
  thenMatchKey: function(key) {
    return function(entry, mx) {
      mx.match(entry, key);
      return true;
    };
  },
  testDirOrExt: function(entry) {
    return entry.isDirectory() || entry.ext;
  },
  evaluateRuleset: function(ruleset, opt) {
    if (opt == null) {
      opt = {};
    }
    ruleset.rule(qrules.classify(/_(.+)_/, 'name0'), qrules.thenMatchKey(opt.key || 'evaluate'));
    return ruleset;
  },
  contextRuleset: function(ruleset, opt) {
    if (opt == null) {
      opt = {};
    }
    ruleset.rule(qrules.any(qrules.classify(/_(.)_(.+)/, 'kind0 name0'), qrules.classify(/_(.+)/, 'name0', qrules.testDirOrExt)), qrules.thenMatchKey(opt.key || 'context'));
    return ruleset;
  },
  compositeRuleset: function(ruleset, opt) {
    if (opt == null) {
      opt = {};
    }
    ruleset.rule(qrules.any(qrules.classify(/(.+)_(.)_/, 'name0 kind0'), qrules.classify(/(.+)_/, 'name0', qrules.testDirOrExt)), qrules.thenMatchKey(opt.key || 'composite'));
    return ruleset;
  },
  simpleRuleset: function(ruleset, opt) {
    if (opt == null) {
      opt = {};
    }
    if (opt.rulesetName === !false) {
      ruleset = ruleset.addRuleset(opt.w || 1.0, opt.rulesetName || 'simple');
    }
    ruleset.rule(qrules.thenMatchKey(opt.key || 'simple'));
    return ruleset;
  },
  standardRuleset: function(host, opt) {
    if (opt == null) {
      opt = {};
    }
    this.evaluateRuleset(host, opt.evaluate);
    this.contextRuleset(host, opt.context);
    this.compositeRuleset(host, opt.composite);
    this.simpleRuleset(host, opt.simple);
    return host;
  }
};

qrules.qrules = qrules;

module.exports = qrules;
