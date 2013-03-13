// Generated by CoffeeScript 1.6.1
var BasicPlugin, CommonPluginBase, CompileRenderPlugin, CompiledPlugin, JsonPlugin, ModulePlugin, PipelinePlugin, RenderedPlugin, StaticPlugin, exports, makeRefError, pluginTypes, qpluginKinds, splitExt,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

qpluginKinds = require('./pluginKinds');

module.exports = exports = Object.create(qpluginKinds);

pluginTypes = exports.pluginTypes;

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

  CommonPluginBase.prototype.notImplemented = function(protocolMethod, entry, callback) {
    var err;
    err = "" + this + "::" + protocolMethod + "() not implemented for {entry: '" + entry.srcRelPath + "'}";
    callback(new Error(err));
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

  CommonPluginBase.prototype.template = function(entry, source, vars, callback) {
    var _this = this;
    return this.context(entry, source, vars, function(err, renderSrcFn) {
      if (err == null) {
        if (typeof renderSrcFn === 'function') {
          return callback(null, renderSrcFn);
        }
        err = new Error("" + _this + " failed to create template function from " + entry);
      }
      return callback(err);
    });
  };

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
    return pluginMap.addPluginForExtIO(this, this.ext, this.intput, this.output);
  };

  BasicPlugin.prototype.render = function(entry, source, vars, callback) {
    return callback(null, source);
  };

  BasicPlugin.prototype.context = function(entry, source, vars, callback) {
    return callback(null, source);
  };

  return BasicPlugin;

})(CommonPluginBase);

exports.BasicPlugin = BasicPlugin;

PipelinePlugin = (function(_super) {

  __extends(PipelinePlugin, _super);

  function PipelinePlugin(list) {
    this.list = list;
  }

  PipelinePlugin.prototype.rename = function(entry) {
    var pi, _i, _len, _ref;
    _ref = this.list;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      pi = _ref[_i];
      entry = pi.rename(entry);
    }
    return entry;
  };

  PipelinePlugin.prototype.adapt = function(entry) {
    var self;
    self = Object.create(this);
    self.list = this.list.map(function(pi) {
      return pi.adapt(entry);
    });
    return self;
  };

  PipelinePlugin.prototype.iterEach = function(callback, eachFn) {
    var pi_list;
    pi_list = this.list.slice();
    return function() {
      var args, err, pi;
      err = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      if (err != null) {
        return callback(err);
      }
      if ((pi = pi_list.shift()) != null) {
        return process.nextTick(function() {
          return eachFn.apply(null, [pi].concat(__slice.call(args)));
        });
      } else {
        return callback.apply(null, arguments);
      }
    };
  };

  PipelinePlugin.prototype.render = function(entry, source, vars, callback) {
    var stepFn;
    stepFn = this.iterEach(callback, function(pi, src) {
      return pi.render(entry, src, vars, stepFn);
    });
    return stepFn(null, source);
  };

  PipelinePlugin.prototype.context = function(entry, source, vars, callback) {
    var stepFn;
    stepFn = this.iterEach(callback, function(pi, src) {
      return pi.context(entry, src, vars, stepFn);
    });
    return stepFn(null, source);
  };

  return PipelinePlugin;

})(BasicPlugin);

exports.PipelinePlugin = PipelinePlugin;

pluginTypes.pipeline = PipelinePlugin;

StaticPlugin = (function(_super) {

  __extends(StaticPlugin, _super);

  function StaticPlugin() {
    return StaticPlugin.__super__.constructor.apply(this, arguments);
  }

  StaticPlugin.prototype.init = function() {
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

  StaticPlugin.prototype.registerPluginOn = function(pluginMap) {
    var ext, _i, _len, _ref, _results;
    pluginMap.addPluginForExtIO(this, this.ext, this.intput, this.output);
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

  StaticPlugin.prototype.renderEx0 = function(entry, vars, callback) {
    entry.touch(false);
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

pluginTypes["static"] = StaticPlugin;

exports.StaticPlugin = StaticPlugin;

RenderedPlugin = (function(_super) {

  __extends(RenderedPlugin, _super);

  function RenderedPlugin() {
    return RenderedPlugin.__super__.constructor.apply(this, arguments);
  }

  RenderedPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  RenderedPlugin.prototype.context = function(entry, source, vars, callback) {
    return this.render(entry, source, vars, callback);
  };

  RenderedPlugin.prototype.render = function(entry, source, vars, callback) {
    if (this.compile == null) {
      return this.notImplemented('render', entry, callback);
    }
    return this.compile(entry, source, function(err, renderFn) {
      return renderFn(vars, callback);
    });
  };

  return RenderedPlugin;

})(BasicPlugin);

pluginTypes.rendered = RenderedPlugin;

exports.RenderedPlugin = RenderedPlugin;

CompiledPlugin = (function(_super) {

  __extends(CompiledPlugin, _super);

  function CompiledPlugin() {
    return CompiledPlugin.__super__.constructor.apply(this, arguments);
  }

  CompiledPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  CompiledPlugin.prototype.render = function(entry, source, vars, callback) {
    return this.notImplemented('render', entry, callback);
  };

  CompiledPlugin.prototype.context = function(entry, source, vars, callback) {
    if (this.compile == null) {
      return this.notImplemented('compile', entry, callback);
    }
    return this.compile(entry, source, callback);
  };

  return CompiledPlugin;

})(BasicPlugin);

pluginTypes.compiled = CompiledPlugin;

exports.CompiledPlugin = CompiledPlugin;

CompileRenderPlugin = (function(_super) {

  __extends(CompileRenderPlugin, _super);

  function CompileRenderPlugin() {
    return CompileRenderPlugin.__super__.constructor.apply(this, arguments);
  }

  CompileRenderPlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  CompileRenderPlugin.prototype.render = RenderedPlugin.prototype.render;

  CompileRenderPlugin.prototype.context = CompiledPlugin.prototype.context;

  return CompileRenderPlugin;

})(BasicPlugin);

pluginTypes.compile_render = CompileRenderPlugin;

exports.CompileRenderPlugin = CompileRenderPlugin;

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

pluginTypes.json = JsonPlugin;

exports.JsonPlugin = JsonPlugin;

ModulePlugin = (function(_super) {

  __extends(ModulePlugin, _super);

  function ModulePlugin() {
    return ModulePlugin.__super__.constructor.apply(this, arguments);
  }

  ModulePlugin.prototype.rename = BasicPlugin.prototype.renameForFormat;

  ModulePlugin.prototype.adapt = function(entry) {
    var mod, self;
    if (!this.accept(entry)) {
      return;
    }
    nsMod.host = self = Object.create(this);
    mod = self.loadModule(entry, nsMod);
    if ((mod != null ? mod.adapt : void 0) != null) {
      return mod.adapt.call(self, entry);
    } else {
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

  ModulePlugin.prototype.loadModule = function(entry) {
    var mod;
    try {
      mod = entry.loadModule();
      return this.initModule(mod, entry);
    } catch (err) {
      return this.error(err);
    }
  };

  ModulePlugin.prototype.initModule = function(mod, entry) {
    var k, v;
    if (mod.initPlugin == null) {
      mod = (typeof mod.initPlugin === "function" ? mod.initPlugin(this, entry) : void 0) || mod;
    }
    for (k in mod) {
      v = mod[k];
      self[k] = v;
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

pluginTypes.module = ModulePlugin;

exports.ModulePlugin = ModulePlugin;
