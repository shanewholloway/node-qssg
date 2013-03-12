# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

qplugins = require('./plugins')
qrules = require('./rules')
qcontent = require('./content')
qentry = require('./entry')
qbuilder = require('./builder')
qutil = require('./util')

class Site
  Object.defineProperties @.prototype,
    site: get: ->@

  #~ initialization

  constructor: (opt={}, plugins)->
    @meta = Object.create opt.meta||@meta||null
    @ctx = Object.create(opt.ctx||null)
    @content = qcontent.createRoot()

    @tasks = qutil.createTaskTracker()
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
    if opt.plugins?
      plugins = @plugins.clone()
      plugins.merge(opt.plugins)
    else plugins = @plugins

    tree = @content.addTree(opt.mount)
    @walker.walkRootContent aPath, tree, plugins

  matchEntryPlugin: (plugin, entry, matchMethod)->
    entry = plugin.rename(entry)
    if (method = plugin[matchMethod])?.call?
      @tasks.defer =>
        method.call plugin, entry, @tasks().wrap (err)->
          console.log "  #{err}" if err?
    else @_plugin_dnu(plugin, matchMethod)

  _plugin_dnu: (plugin, matchMethod)->
    console.warn "#{plugin} does not implement method '#{matchMethod}'"


  build: (rootPath, vars, done)->
    if typeof vars is 'function'
      done = vars; vars = null
    vars = Object.create vars || null, meta:value:@meta
    bldr = qbuilder.createBuilder(rootPath, @content)
    @done -> bldr.build(vars, done)
    return bldr

  done: (done)->
    return done() if @isDone()

    tid = setInterval(=>
        return if not @isDone()
        clearInterval(tid)
        done()
      , 10)

  isDone: ->
    if not @walker.isDone()
      return false
    return @roots.every (e)-> e.isDone()

module.exports =
  Site: Site
  createSite: (opt, plugins)-> new Site(opt, plugins)
  plugins: qplugins.plugins
  createPluginMap: qplugins.createPluginMap

