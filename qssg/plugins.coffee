# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

qpluginMap = require('./pluginMap')
qpluginTypes = require('./pluginTypes')
module.exports = exports = Object.create(qpluginTypes)

{splitExt, pluginTypes} = qpluginTypes


class PluginMap extends qpluginMap.PluginCompositeMap
  Object.defineProperties @.prototype,
    pluginTypes: value: pluginTypes

  constructor:->
    @_initPluginMaps()
    @addDefaultPlugins()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  add: (plugins...)->
    for pi in plugins
      pi.registerPluginOn(@)
    return @

  addPluginForExtIO: (plugin, ext, input, output)->
    @addPluginForKeys(plugin, ext) if ext?
    if output?
      @addPluginForKeys(plugin, ext, output) if ext?
      @addPluginForKeys(plugin, input, output) if input?

  addPluginForKeys: (plugin, input, output)->
    if not plugin.isPlugin
      throw new Error("Expecting a plugin instance")

    input = splitExt(input)
    output = splitExt(output) if output?

    if output?
      for i in input
        for o in output
          @addPluginAt([o,i], plugin)
    else
      for i in input
        @addPluginAt(i, plugin)
    return @invalidate()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  newPluginTypeEx: (key, args)->
    cls = @pluginTypes[key]
    if not cls
      throw new Error("Plugin for type '#{key}' not found")

    pi = new cls()
    pi.init(args...)
    return pi
  newPluginType: (key, args...)->
    return @newPluginTypeEx(key, args)

  addPluginTypeEx: (key, args)->
    @add pi=@newPluginTypeEx(key, args)
    return pi
  addPluginType: (key, args...)->
    return @addPluginTypeEx(key, args)

  addFileType: (obj)->
    if obj.compile?
      return @addPluginTypeEx('compile_render', arguments)
    if obj.render?
      return @addPluginTypeEx('rendered', arguments)
    throw new Error("Unable to find a `compile()` or `render()` method")

  addStaticType: -> @addPluginTypeEx('static', arguments)
  addCompiledType: -> @addPluginTypeEx('compiled', arguments)
  addRenderedType: -> @addPluginTypeEx('rendered', arguments)
  addModuleType: -> @addPluginTypeEx('module', arguments)

  addDefaultPlugins: ->
    @addPluginAt '', @newPluginTypeEx('static')
    @addPluginAt '&', @newPluginTypeEx('composed')

exports.createPluginMap = -> new PluginMap()
exports.plugins = exports.createPluginMap()
exports.PluginMap = PluginMap

