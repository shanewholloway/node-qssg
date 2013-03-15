# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

{inspect} = require('util')
{PipelinePlugin} = require('./pluginTypes')

class PluginBaseMap
  constructor: -> @reset()

  inspect: -> "«#{@constructor.name} | #{Object.keys(@exportPlugins()).join(' | ')} |»"
  toString: -> @inspect()

  countDbKeys: ->
    i=0
    i++ for k of @db
    return i

  invalidate: -> @_cache = {}; return @
  reset: (defaultMode)->
    @db = {}
    @addDefaultPlugins(defaultMode)
    return @invalidate()
  clone: ->
    self = Object.create @
    self.db = Object.create @db
    return self.invalidate()
  freeze: ->
    hash = @exportPlugins()
    return @reset().merge(hash)

  exportPlugins: (hash={})->
    for key, pi of @db
      hash[key] = pi
    return hash
  merge: (plugins)->
    if isFinite(plugins)
      if plugins is true
        return @freeze()
      else if plugins is false or plugins is null
        return @reset()
      else if plugins is 0
        return @reset(false)
      throw new Error("Unknown merge sentinal '#{plugins}' (#{typeof plugins})")
    else
      @addPluginHash plugins.exportPlugins?() or plugins
    return @invalidate()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  addPluginHash: (hash, deep)->
    for key,pi of hash
      if deep or hash.hasOwnProperty(key)
        if @acceptPlugin(key, pi)
          @db[key] = pi
    return @invalidate()
  addPluginAt: (key, pi)->
    if @acceptPlugin(key, pi)
      @db[key] = pi
    return @invalidate()

  acceptPlugin: (key, pi)->
    ans = do ->
      if key[0] is '&'
        return pi.isKindPlugin
      else return pi.isFilePlugin
    return ans

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
    return pi_kind?.composePlugin(pi_list, entry)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module.exports = exports =
  PluginBaseMap: PluginBaseMap

