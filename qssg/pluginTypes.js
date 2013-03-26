//@ sourceMappingURL=pluginTypes.map
// Generated by CoffeeScript 1.6.1
var BasicPlugin, CommonPluginBase, CompileOnlyPlugin, CompilePlugin, JsonPlugin, ModulePlugin, MultiMatchPluginBase, NullPlugin, RenderPlugin, StaticPlugin, deepExtend, exports, makeRefError, qpluginKinds, splitExt,
  __hasProp = {}.hasOwnProperty,
  __slice = [].slice,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

qpluginKinds = require('./pluginKinds');

module.exports = exports = Object.create(qpluginKinds);

deepExtend = require('./util').deepExtend;

exports.splitExt = splitExt = function(ext) {
  if (ext.split != null) {
    ext = ext.split(/[. ;,]+/);
  }
  if (!ext[0]) {
    ext.shift();
  }
  if (!ext[ext.length - 1]) {
    ext.pop();
  }
  return ext;
};

makeRefError = function(key) {
  return {
    get: function() {
      throw new Error("Reference '" + key + "' instead");
    },
    set: function() {
      throw new Error("Reference '" + key + "' instead");
    }
  };
};

CommonPluginBase = (function() {

  function CommonPluginBase() {}

  Object.defineProperties(CommonPluginBase.prototype, {
    pluginName: {
      get: function() {
        return this.name || this.constructor.name;
      }
    },
    inputs: makeRefError('input'),
    outputs: makeRefError('output')
  });

  CommonPluginBase.prototype.registerPluginOn = function(pluginMap) {
    throw new Error("Subclass responsibility (" + this.constructor.name + ")");
  };

  CommonPluginBase.prototype.init = function(opt) {
    if (opt != null) {
      return this.initOptions(opt);
    }
  };

  CommonPluginBase.prototype.initOptions = function(opt) {
    var k, v;
    if (opt != null) {
      for (k in opt) {
        if (!__hasProp.call(opt, k)) continue;
        v = opt[k];
        this[k] = v;
      }
    }
    return this;
  };

  CommonPluginBase.prototype.isFilePlugin = true;

  CommonPluginBase.prototype.inspect = function() {
    if (this.input != null) {
      return "«" + this.pluginName + " '" + this.input + "'»";
    } else {
      return "«" + this.pluginName + "»";
    }
  };

  CommonPluginBase.prototype.toString = function() {
    return this.inspect();
  };

  CommonPluginBase.prototype.splitExt = splitExt;

  CommonPluginBase.prototype.mergeVars = function() {
    var ea, other, vars, _i, _len;
    vars = arguments[0], other = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    for (_i = 0, _len = other.length; _i < _len; _i++) {
      ea = other[_i];
      vars = deepExtend(vars, ea);
    }
    return vars;
  };

  CommonPluginBase.prototype.notImplemented = function(protocolMethod, entry, callback) {
    var err;
    err = "" + this + "::" + protocolMethod + "() not implemented for {entry: '" + entry.srcRelPath + "'}";
    callback(new Error(err));
  };

  CommonPluginBase.prototype.streamAnswer = function(stream, answerFn) {
    var dataList, sendAnswer;
    sendAnswer = function(err) {
      var ans;
      sendAnswer = null;
      if (err != null) {
        return answerFn(err);
      }
      try {
        ans = dataList.join('');
      } catch (err) {
        return answerFn(err);
      }
      return answerFn(null, ans);
    };
    dataList = [];
    stream.on('data', function(data) {
      return dataList.push(data);
    });
    stream.on('error', function(err) {
      return typeof sendAnswer === "function" ? sendAnswer(err) : void 0;
    });
    stream.on('end', function() {
      return typeof sendAnswer === "function" ? sendAnswer() : void 0;
    });
  };

  CommonPluginBase.prototype.adapt = function(entry) {
    return this;
  };

  CommonPluginBase.prototype.rename = function(entry) {
    return entry;
  };

  CommonPluginBase.prototype.render = function(entry, source, vars, callback) {
    return this.notImplemented('render', entry, callback);
  };

  CommonPluginBase.prototype.context = function(entry, source, vars, callback) {
    return this.notImplemented('context', entry, callback);
  };

  if (0) {
    ({
      touchContent: function(entry, citem) {},
      renderStream: function(entry, vars, callback) {
        return this.notImplemented('renderStream', entry, callback);
      }
    });
  }

  return CommonPluginBase;

})();

exports.CommonPluginBase = CommonPluginBase;

BasicPlugin = (function(_super) {

  __extends(BasicPlugin, _super);

  function BasicPlugin() {
    return BasicPlugin.__super__.constructor.apply(this, arguments);
  }

  BasicPlugin.prototype.defaultExt = function() {
    return this.splitExt(this.output)[0];
  };

  BasicPlugin.prototype.renameForFormat = function(entry) {
    var ext0;
    ext0 = entry.ext.pop();
    if (!entry.ext.length) {
      entry.ext.push(this.defaultExt());
    }
    return entry;
  };

  BasicPlugin.prototype.registerPluginOn = function(pluginMap) {
    return pluginMap.addPluginForExtIO(this, this.ext, this.input, this.output);
  };

  return BasicPlugin;

})(CommonPluginBase);

exports.BasicPlugin = BasicPlugin;

MultiMatchPluginBase = (function(_super) {

  __extends(MultiMatchPluginBase, _super);

  function MultiMatchPluginBase() {
    return MultiMatchPluginBase.__super__.constructor.apply(this, arguments);
  }

  MultiMatchPluginBase.prototype.init = function() {
    var opt, options, _i, _len;
    options = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    this.extList = [];
    for (_i = 0, _len = options.length; _i < _len; _i++) {
      opt = options[_i];
      if (opt.length != null) {
        this.extList.push(splitExt(opt));
      } else {
        this.initOptions(opt);
      }
    }
    return this;
  };

  MultiMatchPluginBase.prototype.registerPluginOn = function(pluginMap) {
    var ext, _i, _len, _ref, _results;
    pluginMap.addPluginForExtIO(this, this.ext, this.input, this.output);
    _ref = this.extList || [];
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      ext = _ref[_i];
      if (ext.length === 1) {
        pluginMap.addPluginForKeys(this, ext);
        _results.push(pluginMap.addPluginForKeys(this, ext, '*'));
      } else if (ext.length === 2) {
        _results.push(pluginMap.addPluginForKeys(this, ext.slice(1), ext.slice(0, 1)));
      } else {
        _results.push(console.warn("Ignoreing invalid static extension " + ext));
      }
    }
    return _results;
  };

  return MultiMatchPluginBase;

})(CommonPluginBase);

NullPlugin = (function(_super) {

  __extends(NullPlugin, _super);

  function NullPlugin() {
    return NullPlugin.__super__.constructor.apply(this, arguments);
  }

  NullPlugin.prototype.loadSource = function(entry, source, vars, callback) {
    return callback(null, '');
  };

  NullPlugin.prototype.renderStream = function(entry, vars, callback) {
    return callback(null, null);
  };

  NullPlugin.prototype.render = function(entry, source, vars, callback) {
    return callback(null, '');
  };

  NullPlugin.prototype.context = function(entry, source, vars, callback) {
    return callback(null, '');
  };

  return NullPlugin;

})(CommonPluginBase);

exports.NullPlugin = NullPlugin;

StaticPlugin = (function(_super) {

  __extends(StaticPlugin, _super);

  function StaticPlugin() {
    return StaticPlugin.__super__.constructor.apply(this, arguments);
  }

  StaticPlugin.prototype.touchContent = function(entry, citem) {
    return citem.touch(entry.stat.mtime);
  };

  StaticPlugin.prototype.renderStream = function(entry, vars, callback) {
    return callback(null, entry.readStream());
  };

  StaticPlugin.prototype.render = function(entry, source, vars, callback) {
    return callback(null, source);
  };

  StaticPlugin.prototype.context = function(entry, source, vars, callback) {
    return callback(null, source);
  };

  return StaticPlugin;

})(CommonPluginBase);

exports.StaticPlugin = StaticPlugin;

RenderPlugin = (function(_super) {

  __extends(RenderPlugin, _super);

  function RenderPlugin() {
    return RenderPlugin.__super__.constructor.apply(this, arguments);
  }

  RenderPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  RenderPlugin.prototype.context = function(entry, source, vars, callback) {
    return this.render(entry, source, vars, callback);
  };

  RenderPlugin.prototype.render = function(entry, source, vars, callback) {
    if (this.compile == null) {
      return this.notImplemented('render', entry, callback);
    }
    return this.compile(entry, source, vars, function(err, renderFn) {
      return renderFn(vars, callback);
    });
  };

  return RenderPlugin;

})(BasicPlugin);

exports.RenderPlugin = RenderPlugin;

CompilePlugin = (function(_super) {

  __extends(CompilePlugin, _super);

  function CompilePlugin() {
    return CompilePlugin.__super__.constructor.apply(this, arguments);
  }

  CompilePlugin.prototype.context = function(entry, source, vars, callback) {
    if (this.compile == null) {
      return this.notImplemented('compile', entry, callback);
    }
    return this.compile(entry, source, vars, callback);
  };

  return CompilePlugin;

})(RenderPlugin);

exports.CompilePlugin = CompilePlugin;

CompileOnlyPlugin = (function(_super) {

  __extends(CompileOnlyPlugin, _super);

  function CompileOnlyPlugin() {
    return CompileOnlyPlugin.__super__.constructor.apply(this, arguments);
  }

  CompileOnlyPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  CompileOnlyPlugin.prototype.context = CompilePlugin.prototype.context;

  CompileOnlyPlugin.prototype.render = function(entry, source, vars, callback) {
    return this.notImplemented('render', entry, callback);
  };

  return CompileOnlyPlugin;

})(BasicPlugin);

exports.CompileOnlyPlugin = CompileOnlyPlugin;

JsonPlugin = (function(_super) {

  __extends(JsonPlugin, _super);

  function JsonPlugin() {
    return JsonPlugin.__super__.constructor.apply(this, arguments);
  }

  JsonPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  JsonPlugin.prototype.context = function(entry, source, vars, callback) {
    return this.parse(source, callback);
  };

  JsonPlugin.prototype.render = function(entry, source, vars, callback) {
    return this.parse(source, function(err) {
      return callback(err, source);
    });
  };

  JsonPlugin.prototype.parse = function(source, callback) {
    try {
      return callback(null, JSON.parse(source));
    } catch (err) {
      return callback(err);
    }
  };

  return JsonPlugin;

})(BasicPlugin);

exports.JsonPlugin = JsonPlugin;

ModulePlugin = (function(_super) {

  __extends(ModulePlugin, _super);

  function ModulePlugin() {
    return ModulePlugin.__super__.constructor.apply(this, arguments);
  }

  ModulePlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  ModulePlugin.prototype.adapt = function(entry) {
    var self;
    if (this.accept(entry)) {
      self = Object.create(this);
      self.loadModule(entry);
      return self;
    }
  };

  ModulePlugin.prototype.accept = function(entry) {
    return !entry.ext.some(function(e) {
      return e.match(/\d/);
    });
  };

  ModulePlugin.prototype.error = function(err, entry) {
    console.error("\nModule '" + entry.srcRelPath + "' loading encountered an error");
    console.error(err.stack || err);
    return null;
  };

  ModulePlugin.prototype.loadSource = function(entry, source, vars, callback) {
    return callback(null, '');
  };

  ModulePlugin.prototype.loadModule = function(entry) {
    var mod;
    try {
      mod = entry.loadModule();
      return this.initModule(mod, entry);
    } catch (err) {
      this.error(err, entry);
    }
  };

  ModulePlugin.prototype.initModule = function(mod, entry) {
    var k, v;
    mod = (typeof mod.initPlugin === "function" ? mod.initPlugin(this, entry) : void 0) || mod;
    for (k in mod) {
      v = mod[k];
      this[k] = v;
    }
    return mod;
  };

  ModulePlugin.prototype.render = function(entry, source, vars, callback) {
    return this.notImplemented('render', entry, callback);
  };

  ModulePlugin.prototype.context = function(entry, source, vars, callback) {
    return this.notImplemented('context', entry, callback);
  };

  ModulePlugin.prototype.notImplemented = function(protocolMethod, entry, callback) {
    var err;
    err = "Module '" + entry.srcRelPath + "' does not implement `" + protocolMethod + "()`";
    callback(new Error(err));
  };

  return ModulePlugin;

})(BasicPlugin);

exports.ModulePlugin = ModulePlugin;
