# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

path = require('path')

qplugins = require('./plugins')
qrules = require('./rules')
qcontent = require('./content')
qentry = require('./entry')
qbuilder = require('./builder')
qutil = require('./util')

module.exports = exports = Object.create(qplugins)

class Site
  Object.defineProperties @.prototype,
    site: get: ->@

  #~ initialization

  constructor: (opt={}, plugins)->
    @meta = Object.create opt.meta||@meta||null
    @ctx = Object.create(opt.ctx||null)
    @content = qcontent.createRoot()

    @buildTasks = qutil.invokeList.ordered()
    @_initPlugins(opt, plugins)
    @_initWalker(opt)

  _initWalker: (opt={}) ->
    ruleset = qrules.classifier()
    @initMatchRuleset(ruleset, qrules)

    @walker = qentry.createWalker(@, ruleset)
    @walker.reject(opt.reject || /node_modules/)
    @walker.accept(opt.accept) if opt.accept?
    @walker.filter(opt.filter) if opt.filter?
    @initWalker(@walker)
    return this
  initWalker: (walker)->

  initMatchRuleset: (ruleset, qrules)->
    qrules.standardRuleset(ruleset)

  #~ Plugins

  plugins: qplugins.plugins.clone()
  _initPlugins: (opt, plugins)->
    @plugins = @plugins.clone()
    @plugins.merge(opt.plugins) if opt.plugins?
    @plugins.merge(plugins) if plugins?

  #~ API & context

  walk: (aPath, opt={})->
    if (plugins=opt.plugins)?
      if not plugins?.findPlugin
        plugins = @plugins.clone().merge(plugins)
    else plugins = @plugins

    tree = @content.addTree(path.join('.', opt.mount))
    @walker.walkRootContent aPath, tree, plugins

  rewalkEntry: (entry, c)-> false
  matchEntryPlugin: (entry, pluginFn)->
    try pluginFn @buildTasks
    catch err
      console.warn(entry)
      console.warn(err.stack or err)
      console.warn('')

  invokeBuildTasks: ->
    tasks = qutil.createTaskTracker(arguments...)
    for fn in @buildTasks.sort().slice()
      taskFn = tasks()
      try fn(vars, taskFn)
      catch err then taskFn(err)
    return tasks.seed()

  build: (rootPath, vars, callback)->
    if typeof vars is 'function'
      callback = vars; vars = null
    vars = Object.create vars || null, meta:value:@meta

    bldr = qbuilder.createBuilder(rootPath, @content)
    @walker.done qutil.debounce 1, =>
      @invokeBuildTasks (err, tasks)=>
        bldr.build(vars, callback)
    return bldr

exports.Site = Site
exports.createSite = (opt, plugins)->
  new Site(opt, plugins)

