# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

{PipelinePlugin} = require('./pluginTypes')

class PluginBaseMap
  constructor: ->
    Object.defineProperties @,
      db: value:{}
      _cache: value:{}

  invalidate: ->
    @_cache = {} #Object.create(@db)
    return @
  reset: ->
    @db = {}; return @invalidate()
  clone: ->
    self = Object.create @, db:value:Object.create(@db)
    return self.invalidate()
  freeze: (deep=true)->
    @exportPluginsTo(hash={}, deep)
    return @reset().merge(hash)

  exportPluginsTo: (tgt, deep)->
    if deep
      tgt[key] = pi for key, pi of @db
    else
      tgt[key] = pi for own key, pi of @db
    return tgt
  merge: (plugins)->
    if plugins is true
      return @freeze()
    else if plugins is false
      return @reset()
    else
      if plugins.exportPluginsTo?
        plugins.exportPluginsTo hash={}
      else hash = plugins
      @addPluginHash(hash)
    return @invalidate()

  addPluginHash: (hash, deep)->
    if deep
      for key,pi of hash
        @db[key] = pi if @acceptPlugin(pi)
    else
      for own key,pi of hash
        @db[key] = pi if @acceptPlugin(pi)
    return @invalidate()
  addPluginAt: (keys, pi)->
    if @acceptPlugin(pi)
      keys = [keys] if keys.split?
      for k in keys
        @db[k] = pi
      return @invalidate()
    return @

  acceptPlugin: (pi)->
    throw new Error("Subclass responsibility. (#{@constructor.name})")

  findPluginForExt: (ext, entry)->
    if not (pi=@_cache[ext])?
      @_cache[ext] = pi = @_findPluginForExt(ext, entry)
    return pi
  _findPluginForExt: (ext, entry)->
    throw new Error("Subclass responsibility. (#{@constructor.name})")

  findPluginForKind: (kind0, entry)->
    if kind0?
      pi_kind = @db['&'+kind0]
      if not pi_kind? and kind0.match(/\D/)
        console.warn "Plugin for kind '#{entry.kind0}' not found. (re: #{entry.srcRelPath})"
    return pi_kind || @db['&']

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PluginFilesMap extends PluginBaseMap
  acceptPlugin: (pi)-> pi.isFilePlugin

  _findPluginForExt: (ext, entry)->
    n = ext.length
    if n is 0
      return @db['']
    pi = @db[ext[n-1]]
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
      @db[[fmt,ext]] || # direct match '.fmt.ext'
      @db[[fmt,'*']] || # or middle match: '.fmt.*'
      @db[['*',ext]]  ) # or end match: '.*.ext'

  asPluginPipeline: (pluginList, ext)->
    return new PipelinePlugin(pluginList, ext)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PluginDirsMap extends PluginBaseMap
  acceptPlugin: (pi)-> pi.isDirPlugin

  _findPluginForExt: (ext, entry)->
    if ext.length is 0
      return @db['']
    if ext.length > 1
      console.warn "Multiple extensions on directories are undefined. (re: #{entry.srcRelPath})"
    return @db[ext[0]]

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PluginCompositeMap
  PluginDirsMap: PluginDirsMap
  PluginFilesMap: PluginFilesMap

  _initPluginMaps: ->
    @dirsMap = new @.PluginDirsMap()
    @filesMap = new @.PluginFilesMap()
    return @reset()
  invalidate: ->
    @dirsMap.invalidate()
    @filesMap.invalidate()
    return @
  reset: ->
    @dirsMap.reset()
    @filesMap.reset()
    return @
  clone: ->
    self = Object.create @
    self.dirsMap = @dirsMap.clone()
    self.filesMap = @filesMap.clone()
    return self
  freeze: (deep)->
    @dirsMap.freeze(deep)
    @filesMap.freeze(deep)
    return @
  exportPluginsTo: (tgt, deep)->
    @dirsMap.freeze(tgt, deep)
    @filesMap.freeze(tgt, deep)
    return tgt

  merge: (plugins)->
    @dirsMap.merge(plugins)
    @filesMap.merge(plugins)
    return @
  addPluginHash: (hash)->
    @dirsMap.addPluginHash(hash)
    @filesMap.addPluginHash(hash)
    return @
  addPluginAt: (keys, pi)->
    @dirsMap.addPluginAt(keys, pi)
    @filesMap.addPluginAt(keys, pi)
    return @

  findPluginForExt: (ext, entry, matchKind)->
    if entry.isDirectory()
      return @dirsMap.findPluginForExt(kind0, entry, matchKind)
    else return @filesMap.findPluginForExt(kind0, entry, matchKind)

  findPluginForKind: (kind0, entry, matchKind)->
    if entry.isDirectory()
      return @dirsMap.findPluginForKind(kind0, entry, matchKind)
    else return @filesMap.findPluginForKind(kind0, entry, matchKind)


module.exports = exports =
  PluginBaseMap: PluginBaseMap
  PluginFilesMap: PluginFilesMap
  PluginDirsMap: PluginDirsMap
  PluginCompositeMap: PluginCompositeMap

