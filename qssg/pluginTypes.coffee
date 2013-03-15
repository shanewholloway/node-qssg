# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

qpluginKinds = require('./pluginKinds')
module.exports = exports = Object.create(qpluginKinds)

exports.splitExt = splitExt = (ext)->
  ext = ext.split(/[. ;,]+/) if ext.split?
  ext.shift() if not ext[0]
  ext.pop() if not ext[ext.length-1]
  return ext


makeRefError = (key)->
  get:-> throw new Error("Reference '#{key}' instead")
  set:-> throw new Error("Reference '#{key}' instead")

class CommonPluginBase
  Object.defineProperties @.prototype,
    pluginName: get:-> @name || @.constructor.name
    inputs: makeRefError('input')
    outputs: makeRefError('output')

  registerPluginOn: (pluginMap)->
    throw new Error("Subclass responsibility (#{@constructor.name})")

  init: (opt)-> @initOptions(opt) if opt?
  initOptions: (opt)->
    if opt?
      for own k,v of opt
        @[k] = v
    return @

  isFilePlugin: true
  inspect: ->
    if @input?
      "«#{@pluginName} '#{@input}'»"
    else "«#{@pluginName}»"
  toString: -> @inspect()

  splitExt: splitExt

  notImplemented: (protocolMethod, entry, callback)->
    err = "#{@}::#{protocolMethod}() not implemented for {entry: '#{entry.srcRelPath}'}"
    callback(new Error(err)); return

  streamAnswer: (stream, answerFn)->
    sendAnswer = (err)->
      sendAnswer = null
      return answerFn(err) if err?
      try ans = dataList.join('')
      catch err then return answerFn(err)
      answerFn null, ans

    dataList = []
    stream.on 'data', (data)-> dataList.push(data)
    stream.on 'error', (err)-> sendAnswer?(err)
    stream.on 'end', -> sendAnswer?()
    return

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  adapt: (entry)-> @
  rename: (entry)-> entry

  render: (entry, source, vars, callback)->
    @notImplemented('render', entry, callback)
  context: (entry, source, vars, callback)->
    @notImplemented('context', entry, callback)

  if 0
    touchContent: (entry, citem)->
    renderStream: (entry, vars, callback)->
      @notImplemented('renderStream', entry, callback)

exports.CommonPluginBase = CommonPluginBase

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class BasicPlugin extends CommonPluginBase
  defaultExt: -> @splitExt(@output)[0]
  renameForFormat: (entry)->
    ext0 = entry.ext.pop()
    if not entry.ext.length
      entry.ext.push @defaultExt()
    return entry

  registerPluginOn: (pluginMap)->
    pluginMap.addPluginForExtIO(@, @ext, @input, @output)

exports.BasicPlugin = BasicPlugin


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class MultiMatchPluginBase extends CommonPluginBase
  init: (options...)->
    @extList = []
    for opt in options
      if opt.length?
        @extList.push splitExt(opt)
      else @initOptions(opt)
    return @

  registerPluginOn: (pluginMap)->
    pluginMap.addPluginForExtIO(@, @ext, @input, @output)
    for ext in @extList or []
      if ext.length is 1
        pluginMap.addPluginForKeys(@, ext)
        pluginMap.addPluginForKeys(@, ext, '*')
      else if ext.length is 2
        pluginMap.addPluginForKeys(@, ext.slice(1), ext.slice(0,1))
      else
        console.warn "Ignoreing invalid static extension #{ext}"


class NullPlugin extends CommonPluginBase
  loadSource: (entry, source, vars, callback)->
    callback(null, '')
  renderStream: (entry, vars, callback)->
    callback null, null
  render: (entry, source, vars, callback)->
    callback null, ''
  context: (entry, source, vars, callback)->
    callback null, ''

exports.NullPlugin = NullPlugin


class StaticPlugin extends CommonPluginBase
  touchContent: (entry, citem)->
    citem.touch(entry.stat.mtime)
  renderStream: (entry, vars, callback)->
    callback null, entry.readStream()
  render: (entry, source, vars, callback)->
    callback null, source
  context: (entry, source, vars, callback)->
    callback null, source

exports.StaticPlugin = StaticPlugin


#~ Compiled & Rendered Plugins ~~~~~~~~~~~~~~~~~~~~~~

class RenderPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  context: (entry, source, vars, callback)->
    @render(entry, source, vars, callback)
  render: (entry, source, vars, callback)->
    if not @compile?
      return @notImplemented('render', entry, callback)
    @compile entry, source, vars, (err, renderFn)->
      renderFn(vars, callback)

exports.RenderPlugin = RenderPlugin


class CompilePlugin extends RenderPlugin
  context: (entry, source, vars, callback)->
    if not @compile?
      return @notImplemented('compile', entry, callback)
    @compile(entry, source, vars, callback)

exports.CompilePlugin = CompilePlugin


class CompileOnlyPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  context: CompilePlugin::context
  render: (entry, source, vars, callback)->
    @notImplemented('render', entry, callback)

exports.CompileOnlyPlugin = CompileOnlyPlugin

#~ Node.js provided plugin functionality ~~~~~~~~~~~~

class JsonPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  context: (entry, source, vars, callback)->
    @parse source, callback
  render: (entry, source, vars, callback)->
    @parse source, (err)-> callback(err, source)

  parse: (source, callback)->
    try callback null, JSON.parse(source)
    catch err then callback(err)

exports.JsonPlugin = JsonPlugin


class ModulePlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat

  adapt: (entry)->
    if @accept(entry)
      self = Object.create(@)
      self.loadModule(entry)
      return self

  accept: (entry)-> not entry.ext.some (e)-> e.match(/\d/)
  error: (err, entry)->
    console.error("\nModule '#{entry.srcRelPath}' loading encountered an error")
    console.error(err.stack or err)
    null
  loadSource: (entry, source, vars, callback)->
    callback(null, '')
  loadModule: (entry)->
    try
      mod = entry.loadModule()
      return @initModule(mod, entry)
    catch err
      @error(err, entry); return
  initModule: (mod, entry)->
    mod = mod.initPlugin?(@, entry) || mod
    @[k] = v for k,v of mod
    return mod

  render: (entry, source, vars, callback)->
    @notImplemented('render', entry, callback)
  context: (entry, source, vars, callback)->
    @notImplemented('context', entry, callback)

  notImplemented: (protocolMethod, entry, callback)->
    err = "Module '#{entry.srcRelPath}' does not implement `#{protocolMethod}()`"
    callback(new Error(err)); return

exports.ModulePlugin = ModulePlugin


