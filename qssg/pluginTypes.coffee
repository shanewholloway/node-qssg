# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

assert = require('assert')

makeRefError = (key)->
  get:-> throw new Error("Reference '#{key}' instead")
  set:-> throw new Error("Reference '#{key}' instead")

splitExt = (ext)->
  ext = ext.split(/[. ;,]+/) if ext.split?
  ext.shift() if not ext[0]
  ext.pop() if not ext[ext.length-1]
  return ext
exports.splitExt = splitExt

pluginTypes = {}

class BasePlugin
  Object.defineProperties @.prototype,
    pluginName: get:-> @.constructor.name
    inputs: makeRefError('input')
    outputs: makeRefError('output')

  init: (opt)->
    if opt?
      for own k,v of opt
        @[k] = v
    return @

  inspect: ->
    if @name?
      "«#{@name} plugin»"
    else if @input?
      "«#{@pluginName} '#{@input}'»"
    else "«#{@pluginName}»"
  toString: -> @inspect()

  isPlugin: true
  splitExt: splitExt
  defaultExt: -> @splitExt(@output)[0]

  registerPluginOn: (pluginMap)->
    pluginMap.addPluginForExtIO(@, @ext, @intput, @output)

  #~ plugin protocol

  pluginProtocol: '
    content variable composite compositeDir
    rename bindContent
    '.split(' ')

  content: (entry, vars, answerFn)->
    @notImplemented('content', entry, answerFn)

  simple: (entry, callback)->
    @notImplemented('simple', entry, callback)
  composite: (entry, callback)->
    @notImplemented('composite', entry, callback)
  context: (entry, callback)->
    @notImplemented('context', entry, callback)

  simpleDir: (entry, callback)->
    entry.walk()
    @notImplemented('simpleDir', entry, callback)
  compositeDir: (entry, callback)->
    entry.walk()
    @notImplemented('compositeDir', entry, callback)
  contextDir: (entry, callback)->
    entry.newCtxTree()
    entry.walk()
    @notImplemented('contextDir', entry, callback)

  if 0 # optional plugin protocol
    adapt: (pluginMap, entry, matchKind)-> @

    rename: (entry)-> entry

  bindContent: (entry, callback)->
    contentItem = entry.contentItem || entry.addContent()
    contentItem.renderFn = (vars, answerFn)=>
      @content(entry, vars, answerFn)
    callback()

  #~ plugin protocol utilities

  notImplemented: (protocolMethod, entry, callback)->
    err = "#{@}::#{protocolMethod}() not implemented for {entry: '#{entry.srcRelPath}'}"
    callback(new Error(err)); return


class BasicPlugin0 extends BasePlugin
  compositeDir: (entry, callback)->
    entry.walk()
    callback()
  composite: (entry, callback)->
    @bindContent(entry, callback)

  renameForFormat: (entry)->
    ext0 = entry.ext.pop()
    if not entry.ext.length
      entry.ext.push @defaultExt()
    return entry

class BasicPlugin extends BasicPlugin0
  content: (entry, vars, answerFn)->
    entry.read(answerFn)
  variable: (entry, callback)->
    entry.read(callback)

exports.BasePlugin = BasePlugin
exports.BasicPlugin0 = BasicPlugin0
exports.BasicPlugin = BasicPlugin


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PipelinePlugin extends BasicPlugin
  constructor: (@pluginList, ext)->

  rename: (entry)->
    for pi in @pluginList
      if pi.rename?
        entry = pi.rename(entry)
    return entry

  adapt: (pluginMap, entry, matchKind)->
    self = Object.create(@)
    self.pluginList = @pluginList.map (pi)=>
      if pi.adapt?
        pi = pi.adapt(pluginMap, entry, matchKind)
      return pi
    return self

  content: (entry, vars, answerFn)->
    pluginList = @pluginList.slice()

    renderOverlay = (err, entry_)->
      if err?
        return answerFn(err)
      else
        pi = pluginList.shift()
        pi.content(entry_, vars, answerNext)
      return

    answerNext = (err, what)->
      if err?
        return answerFn(err)
      else if pluginList.length > 0
        try entry.overlaySource(what, renderOverlay)
        catch err then return answerFn(err)
      else answerFn(arguments...)

    renderOverlay(null, entry, entry.readSync())

exports.PipelinePlugin = PipelinePlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


class StaticPlugin extends BasicPlugin
  init: (options...)->
    @extList = []
    for opt in options
      if opt.length?
        @extList.push splitExt(opt)
      else
        for own k,v of opt
          @[k] = v
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

  content: (entry, vars, callback)->
    entry.touch(false)
    callback(null, entry.readStream())
  variable: (entry, callback)->
    entry.read(callback)
pluginTypes.static = StaticPlugin
exports.StaticPlugin = StaticPlugin


class RenderedPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  adapt: (pluginMap, entry, matchKind)->
    return Object.create(@) # clone this instance

  content: (entry, vars, callback)->
    @renderEntry(entry.extendVars(vars), callback)
  variable: (entry, callback)->
    @renderEntry(entry, entry.extendVars(), callback)

  renderEntry: (entry, vars, callback)->
    if @renderFile?
      @renderFile(entry, entry.srcPath, vars, callback)
    else if @render?
      entry.read (err, data)=>
        if data?
          @render(entry, data, vars, callback)
        else callback(err)
    else if @compileEntry?
      @compileEntry entry, vars, (err, boundRenderFn)->
        if boundRenderFn?
          boundRenderFn(vars, callback)
        else callback(err)
    else
      @notImplemented('render', entry, callback)
    return

pluginTypes.rendered = RenderedPlugin
exports.RenderedPlugin = RenderedPlugin


class CompiledPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  adapt: (pluginMap, entry, matchKind)->
    return Object.create(@) # clone this instance

  variable: (entry, callback)->
    @compileEntry(entry, entry.extendVars(), callback)

  compileEntry: (entry, vars, callback)->
    if @compileFile?
      @compileFile(entry, entry.srcPath, vars, callback)
    else if @compile?
      entry.read (err, data)=>
        if data?
          @compile(entry, data, vars, callback)
        else callback(err, data)
    else
      @notImplemented('compile', entry, callback)
    return

pluginTypes.compiled = CompiledPlugin
exports.CompiledPlugin = CompiledPlugin

class CompileRenderPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  adapt: (pluginMap, entry, matchKind)->
    return Object.create(@) # clone this instance
  content: RenderedPlugin::content
  renderEntry: RenderedPlugin::renderEntry
  variable: CompiledPlugin::variable
  compileEntry: CompiledPlugin::compileEntry

pluginTypes.compile_render = CompileRenderPlugin
exports.CompileRenderPlugin = CompileRenderPlugin


class ModulePlugin extends BasePlugin
  rename: BasicPlugin::renameForFormat
  notImplemented: (protocolMethod, entry, callback)->
    err = "Module '#{entry.srcRelPath}' does not implement `#{protocolMethod}()`"
    callback(new Error(err)); return

  adapt: (pluginMap, entry, matchKind)->
    nsMod = {entry:entry, matchKind:matchKind, pluginMap:pluginMap, host:@}
    return if not @accept(entry, nsMod)

    nsMod.host = self = Object.create(@)
    mod = self.load(entry, nsMod)
    return if not mod?

    for meth in @pluginProtocol
      self[meth] = mod[meth] if mod[meth]?
    return self

  accept: (entry, nsMod)->
    not entry.ext.some (e)-> e.match(/\d/)
  result: (mod, nsMod)-> mod
  error: (err, nsMod)->
    console.error("\nModule '#{nsMod.entry.srcRelPath}' loading encountered an error")
    console.error(err.stack or err)
    null
  load: (entry, nsMod)->
    try
      mod = entry.loadModule()
      if mod.initPlugin?
        mod = mod.initPlugin?(nsMod) || mod
      return @result(mod, nsMod)
    catch err
      return @error(err, nsMod)

pluginTypes.module = ModulePlugin
exports.ModulePlugin = ModulePlugin


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~ Plugin Factory
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PluginFactory
  Object.defineProperties @,
    types: value: pluginTypes

  Object.defineProperties @.prototype,
    types: value: pluginTypes

  constructor: ->
    @types = Object.create(@types)

  _initPluginOn: (pi, args)->
    pi.init(args...)
    pi.registerPluginOn(@)
    return pi

  asPluginPipeline: (pluginList, ext)->
    return new PipelinePlugin(pluginList, ext)

  addPluginTypeEx: (key, args)->
    cls = @types[key]
    if not cls
      throw new Error("Plugin for type '#{key}' not found")
    return @_initPluginOn(new cls, args)
  addPluginType: (key, args)->
    return @addPluginTypeEx(key, args)

  addFileType: (obj)->
    if obj.compile?
      key = 'compile_render'
    else if obj.render?
      key = 'rendered'
    else throw new Error("Unable to find a `compile()` or `render()` method")
    return @addPluginTypeEx(key, arguments)

  addStaticType: -> @addPluginTypeEx('static', arguments)
  addCompiledType: -> @addPluginTypeEx('compiled', arguments)
  addRenderedType: -> @addPluginTypeEx('rendered', arguments)
  addModuleType: -> @addPluginTypeEx('module', arguments)

exports.PluginFactory = PluginFactory
exports.types = pluginTypes

