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
    Object.defineProperty @, 'map', value: {}
    @invalidate()
    @default = @addStaticType()
  clone: ->
    map = Object.create(@map)
    return Object.create(@, map:value:map).invalidate()

  invalidate: ->
    @_cache = Object.create(@map); return @

  findPlugin: (entry, matchKey)->
    ext = entry.ext
    if entry.kind0?
      (ext=ext.slice(0)).unshift entry.kind0+':'

    if not (pi=@_cache[ext])?
      @_cache[ext] = pi = @findPluginForExt(ext)
    if pi.adapt?
      pi = pi.adapt(@, entry, matchKey)
    return pi or @default

  findPluginForExt: (ext)->
    n = ext.length
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

  addPlugin: (extList, plugin)->
    if not plugin.isPlugin?()
      throw new Error("Expecting a plugin instance")
    extList = [extList] if extList.split?
    for ext in extList
      @map[splitExt(ext)] = plugin
    @invalidate()

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
    if plugins.addPluginsTo?
      plugins.addPluginsTo(@map)
    else
      for own key,pi of plugins
        if pi.content? and pi.variable?
          @map[key] = pi
    return @invalidate()

g_plugins = new PluginMap()
exports.PluginMap = PluginMap
exports.plugins = g_plugins

