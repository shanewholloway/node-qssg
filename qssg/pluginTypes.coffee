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

exports.pluginTypes = pluginTypes = Object.create(exports.pluginTypes || null)

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

  isPlugin: true
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

  pluginProtocol: ['adapt','rename', 'bindRender', 'bindContext', 'render', 'context']

  adapt: (entry)-> @
  rename: (entry)-> entry

  bindRender: (entry, callback)->
    @rename(entry)
    citem = entry.addContent()
    citem.renderFn = @render.bind(entry)
    callback(null, citem)
  render: (entry, vars, answerFn)->
    @notImplemented('render', entry, answerFn)

  bindContext: (entry, callback)->
    @context entry, (err, value)->
      if not (value is undefined)
        entry.ctx_w[entry.name0] = value
      callback(err, value)
  context: (entry, callback)->
    @notImplemented('context', entry, callback)


class DirPluginBase extends CommonPluginBase
  isDirPlugin: true

  pluginProtocol:
    CommonPluginBase::pluginProtocol.concat [
      'contentDir', 'bindContextDir']

  contentDir: (entry, callback)->
    if entry.ext.length is 0
      ctree = entry.addContentTree()
      callback(null, ctree)
    else
      ctree = entry.newContentTree()
      @bindRender(entry, callback)
    entry.walk()

  bindContextDir: (entry, callback)->
    if entry.ext.length>0
      console.warn 'Context directories with extensions are not defined'
    ctree = entry.newCtxTree()
    entry.walk()
    callback(null, ctree)

  render: (entry, vars, answerFn)->
    di = entry.contentTree?.items[entry.name]
    if not di? or not di.renderFn?
      answerFn("Entry '#{entry.name}' not defined for composite")
    else
      di.renderFn(arguments...)


class FilePluginBase extends CommonPluginBase
  isFilePlugin: true

class CombinedPluginBase extends DirPluginBase
  isFilePlugin: true

exports.CommonPluginBase = CommonPluginBase
exports.DirPluginBase = DirPluginBase
exports.FilePluginBase = FilePluginBase
exports.CombinedPluginBase = CombinedPluginBase

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class BasicPlugin extends FilePluginBase
  defaultExt: -> @splitExt(@output)[0]
  renameForFormat: (entry)->
    ext0 = entry.ext.pop()
    if not entry.ext.length
      entry.ext.push @defaultExt()
    return entry

  registerPluginOn: (pluginMap)->
    pluginMap.addPluginForExtIO(@, @ext, @intput, @output)

  render: (entry, vars, answerFn)->
    entry.read(answerFn)
  context: (entry, callback)->
    entry.read(callback)

exports.BasicPlugin = BasicPlugin


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class PipelinePlugin extends BasicPlugin
  constructor: (@pluginList, ext)->

  rename: (entry)->
    for pi in @pluginList
      entry = pi.rename(entry)
    return entry

  adapt: (entry)->
    self = Object.create(@)
    self.pluginList = @pluginList.map (pi)-> pi.adapt(entry)
    return self

  render: (entry, vars, answerFn)->
    pluginList = @pluginList.slice()

    renderOverlay = (err, entry_)->
      if err?
        return answerFn(err)
      else
        pi = pluginList.shift()
        pi.render(entry_, vars, answerNext)
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


class StaticPlugin extends CombinedPluginBase
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

  render: (entry, vars, callback)->
    entry.touch(false)
    callback(null, entry.readStream())
  context: (entry, callback)->
    entry.read(callback)
pluginTypes.static = StaticPlugin
exports.StaticPlugin = StaticPlugin


class RenderedPlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat
  render: (entry, vars, callback)->
    @renderEntry(entry.extendVars(vars), callback)
  context: (entry, callback)->
    @render(entry, {}, callback)

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
  context: (entry, callback)->
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
  render: RenderedPlugin::render
  renderEntry: RenderedPlugin::renderEntry
  context: CompiledPlugin::context
  compileEntry: CompiledPlugin::compileEntry

pluginTypes.compile_render = CompileRenderPlugin
exports.CompileRenderPlugin = CompileRenderPlugin


class ModulePlugin extends BasicPlugin
  rename: BasicPlugin::renameForFormat

  adapt: (entry)->
    nsMod = {entry:entry, host:@}
    return if not @accept(entry, nsMod)

    nsMod.host = self = Object.create(@)
    mod = self.load(entry, nsMod)
    return if not mod?

    for meth in @pluginProtocol
      self[meth] = mod[meth] if mod[meth]?
    if mod.adapt?
      return mod.adapt.call(self, entry)
    else return self

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

  render: (entry, vars, answerFn)->
    @notImplemented('render', entry, answerFn)
  context: (entry, callback)->
    @notImplemented('context', entry, callback)

  notImplemented: (protocolMethod, entry, callback)->
    err = "Module '#{entry.srcRelPath}' does not implement `#{protocolMethod}()`"
    callback(new Error(err)); return

pluginTypes.module = ModulePlugin
exports.ModulePlugin = ModulePlugin


