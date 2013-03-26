//@ sourceMappingURL=plugins.map
// Generated by CoffeeScript 1.6.1
var KindPlugin, NullPlugin, PluginMap, StaticPlugin, exports, qpluginMap, qpluginTypes, splitExt,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

qpluginMap = require('./pluginMap');

qpluginTypes = require('./pluginTypes');

module.exports = exports = Object.create(qpluginTypes);

KindPlugin = qpluginTypes.KindPlugin, StaticPlugin = qpluginTypes.StaticPlugin, NullPlugin = qpluginTypes.NullPlugin, splitExt = qpluginTypes.splitExt;

PluginMap = (function(_super) {

  __extends(PluginMap, _super);

  function PluginMap() {
    return PluginMap.__super__.constructor.apply(this, arguments);
  }

  PluginMap.prototype.addDefaultPlugins = function(mode) {
    if (mode === false || mode === 'no-op') {
      this.addPluginAt('', new NullPlugin());
    } else {
      this.addPluginAt('', new StaticPlugin());
    }
    return this.addPluginAt('&', new KindPlugin());
  };

  PluginMap.prototype.add = function() {
    var pi, plugins, _i, _len;
    plugins = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    for (_i = 0, _len = plugins.length; _i < _len; _i++) {
      pi = plugins[_i];
      if (typeof pi === 'function') {
        pi = new pi();
      }
      pi.registerPluginOn(this);
    }
    return this;
  };

  PluginMap.prototype.addPluginForExtIO = function(plugin, ext, input, output) {
    if (ext != null) {
      this.addPluginForKeys(plugin, ext);
    }
    if (output != null) {
      if (ext != null) {
        this.addPluginForKeys(plugin, ext, output);
      }
      if (input != null) {
        return this.addPluginForKeys(plugin, input, output);
      }
    }
  };

  PluginMap.prototype.addPluginForKeys = function(plugin, input, output) {
    var i, o, _i, _j, _k, _len, _len1, _len2;
    if (!plugin.isFilePlugin) {
      throw new Error("Expecting a file plugin instance");
    }
    input = splitExt(input);
    if (output != null) {
      output = splitExt(output);
    }
    if (output != null) {
      for (_i = 0, _len = input.length; _i < _len; _i++) {
        i = input[_i];
        for (_j = 0, _len1 = output.length; _j < _len1; _j++) {
          o = output[_j];
          this.addPluginAt([o, i], plugin);
        }
      }
    } else {
      for (_k = 0, _len2 = input.length; _k < _len2; _k++) {
        i = input[_k];
        this.addPluginAt(i, plugin);
      }
    }
    return this.invalidate();
  };

  PluginMap.prototype.addStatic = function() {
    var pi;
    pi = new StaticPlugin();
    this.add(pi.init.apply(pi, arguments));
    return pi;
  };

  PluginMap.prototype.addStaticType = PluginMap.prototype.addStatic;

  return PluginMap;

})(qpluginMap.PluginBaseMap);

exports.createPluginMap = function() {
  return new PluginMap();
};

exports.plugins = exports.createPluginMap();

exports.PluginMap = PluginMap;
