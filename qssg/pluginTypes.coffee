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
pluginTypes = exports.pluginTypes

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

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  adapt: (entry)-> @
  rename: (entry)-> entry

  if 0
    render: (entry, source, vars, callback)->
      @notImplemented('render', entry, callback)
    context: (entry, source, vars, callback)->
      @notImplemented('context', entry, callback)

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
    pluginMap.addPluginForExtIO(@, @ext, @intput, @output)

exports.BasicPlugin = BasicPlugin


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class StaticPlugin extends CommonPluginBase
  init: (options...)->
    @extList = []
    for opt in options
      if opt.length?
        @extList.push splitExt(opt)
      else @initOptions(opt)
    return @

  registerPluginOn: (pluginMap)->
    pluginMap.addPluginForExtIO(@, @ext, @intput, @output)
    for ext in @extList or []
      if ext.length is 1
        pluginMap.addPluginForKeys(@, ext)
        pluginMap.addPluginForKeys(@, ext, '*')
      else if ext.length is 2
        pluginMap.addPluginForKeys(@, ext.slice(1), ext.slice(0,1))
      else
        console.warn "Ignoreing invalid static extension #{ext}"

pluginTypes.static = StaticPlugin
exports.StaticPlugin = StaticPlugin


#~ Compiled & Rendered Plugins ~~~~~~~~~~~~~~~~~~~~~~

class RenderedPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  context: (entry, source, vars, callback)->
    @render(entry, source, vars, callback)
  render: (entry, source, vars, callback)->
    if not @compile?
      return @notImplemented('render', entry, callback)
    @compile entry, source, (err, renderFn)->
      renderFn(vars, callback)

pluginTypes.rendered = RenderedPlugin
exports.RenderedPlugin = RenderedPlugin


class CompiledPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  render: (entry, source, vars, callback)->
    @notImplemented('render', entry, callback)
  context: (entry, source, vars, callback)->
    if not @compile?
      return @notImplemented('compile', entry, callback)
    @compile(entry, source, callback)

pluginTypes.compiled = CompiledPlugin
exports.CompiledPlugin = CompiledPlugin

class CompileRenderPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  render: RenderedPlugin::render
  context: CompiledPlugin::context

pluginTypes.compile_render = CompileRenderPlugin
exports.CompileRenderPlugin = CompileRenderPlugin


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

pluginTypes.json = JsonPlugin
exports.JsonPlugin = JsonPlugin


class ModulePlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat

  adapt: (entry)->
    return if not @accept(entry)

    nsMod.host = self = Object.create(@)
    mod = self.loadModule(entry, nsMod)
    if mod?.adapt?
      return mod.adapt.call(self, entry)
    else return self

  accept: (entry)-> not entry.ext.some (e)-> e.match(/\d/)
  error: (err, entry)->
    console.error("\nModule '#{entry.srcRelPath}' loading encountered an error")
    console.error(err.stack or err)
    null
  loadModule: (entry)->
    try
      mod = entry.loadModule()
      return @initModule(mod, entry)
    catch err
      return @error(err)
  initModule: (mod, entry)->
    if not mod.initPlugin?
      mod = mod.initPlugin?(@, entry) || mod
    self[k] = v for k,v of mod
    return mod

  render: (entry, source, vars, callback)->
    @notImplemented('render', entry, callback)
  context: (entry, source, vars, callback)->
    @notImplemented('context', entry, callback)

  notImplemented: (protocolMethod, entry, callback)->
    err = "Module '#{entry.srcRelPath}' does not implement `#{protocolMethod}()`"
    callback(new Error(err)); return

pluginTypes.module = ModulePlugin
exports.ModulePlugin = ModulePlugin


