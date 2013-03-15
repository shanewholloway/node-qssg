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

{StaticPlugin, KindPlugin, splitExt} = qpluginTypes


class PluginMap extends qpluginMap.PluginBaseMap
  addDefaultPlugins: ->
    @addPluginAt '', new StaticPlugin()
    @addPluginAt '&', new KindPlugin()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  add: (plugins...)->
    for pi in plugins
      if typeof pi is 'function'
        pi = new pi()
      pi.registerPluginOn(@)
    return @

  addPluginForExtIO: (plugin, ext, input, output)->
    @addPluginForKeys(plugin, ext) if ext?
    if output?
      @addPluginForKeys(plugin, ext, output) if ext?
      @addPluginForKeys(plugin, input, output) if input?

  addPluginForKeys: (plugin, input, output)->
    if not plugin.isFilePlugin
      throw new Error("Expecting a file plugin instance")

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

  addStatic: ->
    pi = new StaticPlugin()
    @add pi.init(arguments...)
    return pi
  addStaticType: @::addStatic

exports.createPluginMap = -> new PluginMap()
exports.plugins = exports.createPluginMap()
exports.PluginMap = PluginMap

