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
    Object.defineProperties @, db:value:{}

  inspect: -> "«#{@constructor.name}»"
  toString: -> @inspect()

  invalidate: ->
    @_cache = {}
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
    db = @db
    for key, pi of db
      if deep or Object.hasOwnProperty(db, key)
        tgt[key] = pi
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

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  addPluginHash: (hash, deep)->
    for key,pi of hash
      if deep or Object.hasOwnProperty(hash, key)
        if @acceptPlugin(key, pi)
          @db[key] = pi
    return @invalidate()
  addPluginAt: (key, pi)->
    if @acceptPlugin(key, pi)
      @db[key] = pi
    return @invalidate()

  acceptPlugin: (key, pi)->
    if key[0] is '&'
      return pi.isKindPlugin
    else return pi.isFilePlugin

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  findPluginListForExt: (ext, entry)->
    if not (pi_list=@_cache[ext])?
      @_cache[ext] = pi_list = @_findPluginListForExt(ext, entry)
    return pi_list.slice()
  default: -> @db['']

  _findPluginListForExt: (ext, entry)->
    n = ext.length
    return [@db['']] if n is 0

    pi = @db[ext[n-1]]
    return [pi or @default()] if n is 1

    pi_list = (@_lookupPair(ext[i],ext[i+1]) for i in [n-2..0])
    pi_list[0] ||= pi

    # trim off the list after the first undefined
    i = pi_list.indexOf(undefined)
    pi_list.splice(i) if ~i
    if pi_list.length is 0
      pi_list.push @default()
    return pi_list
  _lookupPair: (fmt,ext)-> return (
      @db[[fmt,ext]] || # direct match '.fmt.ext'
      @db[[fmt,'*']] || # or middle match: '.fmt.*'
      @db[['*',ext]]  ) # or end match: '.*.ext'

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  findPluginForKind: (kind0, entry)->
    if kind0?
      pi_kind = @db['&'+kind0]
      if not pi_kind? and kind0.match(/\D/)
        console.warn "Plugin for kind '#{entry.kind0}' not found. (re: #{entry.srcRelPath})"
      return pi_kind if pi_kind?
    return @db['&']

  findPlugin: (entry)->
    if not entry.isDirectory()
      pi_list = @findPluginListForExt(entry.ext, entry)
    pi_kind = @findPluginForKind(entry.kind0, entry)
    return pi_kind.composePlugin(pi_list, entry)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module.exports = exports =
  PluginBaseMap: PluginBaseMap

