# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

qutil = require('./util')

exports.pluginTypes = pluginTypes = {}

class PluginCompositeTasks
  bindLoadSource: ->
    pi = @plugins[0]
    return (_, vars, callback)=>
      if pi?.loadSource?
        pi.loadSource(@entry, vars, callback)
      else @entry.read callback

  bindPipelineFn: (tasks, ns)->
    return (source, vars, answerFn)=>
      if ns?
        vars = Object.create(vars)
        vars[k]=v for k,v of ns
      vars?.output?.plugins = @
      q = tasks.slice()
      stepFn = (err, src)->
        if not err? and (fn = q.shift())?
          try return fn(src, vars, stepFn)
          catch err then answerFn(err)
        else answerFn(err, src)
      stepFn(null, source)

  bindRenderTasks: (tasks=[], allowStream)->
    entry = @entry
    pi_render_fn = (source, vars, callback)->
      vars?.output?.pi_tip = @
      try @render(entry, source, vars, callback)
      catch err then callback(err)
        
    tasks.push @bindLoadSource()
    for pi in @plugins
      tasks.push pi_render_fn.bind(pi)
    return tasks
  bindRenderFn: (ns)->
    @bindPipelineFn @bindRenderTasks(), ns
  bindRenderContent: ->
    citem = @entry.bindContent()
    for pi in @plugins
      pi.touchContent?(@entry, citem)

    if @plugins.length is 1 and pi.renderStream?
      citem.bindRender pi.renderStream.bind(pi, @entry)
    else
      citem.bindRenderComposed()
      citem.renderTasks().push @bindRenderFn()
    return citem

  bindTemplateFn: (ns)->
    renderFn = @bindRenderFn(ns)
    tmplFn = (source, vars, answerFn)=>
      vars = Object.create vars, content:value:source
      renderFn(vars, answerFn)
    return tmplFn
  addTemplate: (tmplFn, order=@templateOrder)->
    if not tmplFn?
      tmplFn = @bindTemplateFn(null)
    @entry.getContent().addTemplate(tmplFn, order)
  templateOrder: 0


  bindContextTasks: (tasks=[])->
    entry = @entry
    pi_context_fn = (source, vars, callback)->
      vars?.output?.pi_tip = @
      try @context(entry, source, vars, callback)
      catch err then callback(err)

    tasks.push @bindLoadSource()
    for pi in @plugins
      tasks.push pi_context_fn.bind(pi)
    return tasks
  bindContextFn: (ns)->
    @bindPipelineFn @bindContextTasks(), ns

  setContext: (vars={}, callback)->
    if typeof vars is 'function'
      callback = vars; vars = {}
    ctxFn = @bindContextFn()
    ctxFn vars, (err, value)=>
      @entry.setCtxValue(value) if not err?
      callback?(err, value)

  setMetadata: (vars={}, callback)->
    if typeof vars is 'function'
      callback = vars; vars = {}
    ctxFn = @bindContextFn()
    ctxFn vars, (err, metadata)=>
      if not err? and metadata?
        citem = @entry.getContent()
        for k,v of metadata
          citem.meta[k]=v
      callback?(err, metadata)

exports.PluginCompositeTasks = PluginCompositeTasks

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class KindBasePlugin extends PluginCompositeTasks
  isKindPlugin: true

  kinds: ''
  registerPluginOn: (pluginMap)->
    pluginMap.addPluginAt '&'+@kind

  init: (opt)-> @initOptions(opt) if opt?
  initOptions: (opt)->
    if opt?
      for own k,v of opt
        @[k] = v
    return @

  inspect: -> "«#{@constructor.name}: [#{@plugins.join(', ')}]»"
  toString: -> @inspect()

  composePlugin: (plugins, entry, matchMethod)->
    plugins ||= []
    @extendPlugins?(plugins)
    for pi,i in plugins
      plugins[i] = pi = pi.adapt(entry)
      entry = pi.rename(entry) if pi?
    plugins = plugins.filter (e)->e?

    self = Object.create @,
      plugins:value:plugins
      entry:value:entry
    self.initComposed?()
    return self

  bindPluginFn: (matchMethod)-> @[matchMethod].bind(@)

  notImplemented: (protocolMethod)->
    throw new Error "#{@}::#{protocolMethod}() not implemented for {entry: '#{@entry.srcRelPath}'}"

  simple: (buildTasks)-> @notImplemented('simple')
  composite: (buildTasks)-> @notImplemented('composite')
  context: (buildTasks)-> @notImplemented('context')
  simpleDir: (buildTasks)-> @notImplemented('simpleDir')
  compositeDir: (buildTasks)-> @notImplemented('compositeDir')
  contextDir: (buildTasks)-> @notImplemented('contextDir')

exports.KindBasePlugin = KindBasePlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class KindPlugin extends KindBasePlugin
  buildOrder: 2

  simple: (buildTasks)->
    @bindRenderContent()
  composite: (buildTasks)->
    @bindRenderContent()
  context: (buildTasks)->
    buildTasks.add @buildOrder, (taskFn)=>
      @setContext({}, taskFn)

  simpleDir: (buildTasks)->
    if @entry.ext.length
      return @compositeDir(@entry)
    ctree = @entry.addContentTree()
    @entry.walk()
  compositeDir: (buildTasks)->
    ctree = @entry.addComposite()
    @entry.walk()
  contextDir: (buildTasks)->
    if @entry.ext.length>0
      console.warn 'Context directories with extensions are not defined'
    ctree = @entry.newCtxTree()
    @entry.walk()

exports.KindPlugin = KindPlugin
pluginTypes.kind = KindPlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class TemplatePlugin extends KindBasePlugin
  templateOrder: 1
  buildOrder: 5

  composite: (buildTasks)->
    buildTasks.add @buildOrder, (taskFn)=>
      @addTemplate()
      taskFn()
  context: (buildTasks)->
    buildTasks.add @buildOrder, =>
      @entry.setCtxTemplate @bindTemplateFn()
      taskFn()

exports.TemplatePlugin = TemplatePlugin
pluginTypes.template = TemplatePlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class MetadataPlugin extends KindBasePlugin
  buildOrder: -1

  composite: (buildTasks)->
    buildTasks.add @buildOrder, (taskFn)=>
      @setMetadata(taskFn)
  context: (buildTasks)->
    buildTasks.add @buildOrder, (taskFn)=>
      @setMetadata(taskFn)

exports.TemplatePlugin = TemplatePlugin
pluginTypes.template = TemplatePlugin

