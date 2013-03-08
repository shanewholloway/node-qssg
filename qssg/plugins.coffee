# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

qpluginTypes = require('./pluginTypes')
{splitExt, PluginFactory} = qpluginTypes
exports = module.exports = Object.create(qpluginTypes)

class PluginMap extends PluginFactory
  constructor:->
    super()
    @reset()
  reset: (map={})->
    Object.defineProperties @,
      map:value:map
    @default = @addStaticType()
    return @invalidate()
  freeze: (map)->
    @addPluginsTo(map={}, true) if not map?
    Object.defineProperty @, 'map', value: map
    return @invalidate()
  clone: ->
    self = Object.create @,
      map:value:Object.create(@map)
    return self.invalidate()
  invalidate: ->
    @_cache = Object.create(@map); return @

  findPlugin: (entry, matchKind)->
    pi = @findPluginForExt(entry.ext) or @default
    if pi.adapt?
      pi = pi.adapt(@, entry, matchKind)
    return pi or @default

  findPluginForExt: (ext)->
    if not (pi=@_cache[ext])?
      @_cache[ext] = pi = @_findPluginForExt(ext)
    return pi

  _findPluginForExt: (ext)->
    n = ext.length
    if n is 0
      return @map[0]
    pi = @map[ext[n-1]]
    if n > 1
      pi_list = (@_lookupPair(ext[i],ext[i+1]) for i in [n-2..0])
      pi_list[0] ||= pi

      # trim off the list after the first undefined
      i = pi_list.indexOf(undefined)
      pi_list.splice(i) if ~i

      if pi_list.length > 1
        pi = @asPluginPipeline(pi_list, ext)
      else pi = pi_list.pop()

    return pi or @default
  _lookupPair: (fmt,ext)-> return (
      @map[[fmt,ext]] || # direct match '.fmt.ext'
      @map[[fmt,'*']] || # or middle match: '.fmt.*'
      @map[['*',ext]]  ) # or end match: '.*.ext'

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  add: (plugins...)->
    for pi in plugins
      pi.registerPluginOn(@)
    return @

  addPlugin: (extList, plugin)->
    if not plugin.isPlugin?()
      throw new Error("Expecting a plugin instance")
    extList = [extList] if extList.split?
    for ext in extList
      @map[splitExt(ext)] = plugin
    @invalidate()

  addPluginForExtIO: (plugin, ext, input, output)->
    @addPluginForKeys(plugin, ext) if ext?
    if output?
      @addPluginForKeys(plugin, ext, output) if ext?
      @addPluginForKeys(plugin, input, output) if input?

  addPluginForKeys: (plugin, input, output)->
    if not plugin.isPlugin?()
      throw new Error("Expecting a plugin instance")

    input = splitExt(input)
    output = splitExt(output) if output?

    if output?
      for i in input
        for o in output
          @map[[o,i]] = plugin
          #console.log 'reg:', [o,i], plugin
    else
      for i in input
        @map[i] = plugin
        #console.log 'reg:', [i], plugin
    return @invalidate()

  addPluginsTo: (tgt, deep)->
    if deep
      tgt[key] = pi for key, pi of @map
    else
      tgt[key] = pi for own key, pi of @map
    return tgt
  merge: (plugins)->
    if plugins is true
      return @freeze()
    else if plugins is false
      return @reset()
    else if plugins.addPluginsTo?
      plugins.addPluginsTo(@map)
    else
      for own key,pi of plugins
        if pi.content? and pi.variable?
          @map[key] = pi
    return @invalidate()

exports.createPluginMap = -> new PluginMap()
exports.plugins = exports.createPluginMap()
exports.PluginMap = PluginMap

