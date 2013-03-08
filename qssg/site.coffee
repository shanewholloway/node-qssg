# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

tromp = require('tromp')

qplugins = require('./plugins')
qrules = require('./rules')
qcontent = require('./content')
{SiteBuilder} = require('./builder')
{MatchEntry} = require('./entry')

class MatchingWalker extends tromp.WalkRoot
  constructor: (@ruleset, @tasks)->
    super(autoWalk: false)
    Object.defineProperty @, '_self_', value:@

  instance: (content, pluginMap)->
    Object.create @_self_,
      content:{value:content}
      pluginMap:{value:pluginMap||@pluginMap}

  walkListing: (listing)->
    if (entry = listing.node.entry)?
      if not (tree = entry.tree)?
        tree = entry.addContentTree()
      return @instance(tree, entry.pluginMap)
    return @

  walkRootContent: (aPath, content, pluginMap)->
    @instance(content, pluginMap).walk(aPath)

  walkNotify: (op, args...)->
    @["_op_"+op]?.apply(@, args)
  _op_dir: (entry)->
    entry = new MatchEntry(entry, @content, @pluginMap)
    @ruleset.matchRules(entry, @)
  _op_file: (entry)->
    entry = new MatchEntry(entry, @content, @pluginMap)
    @ruleset.matchRules(entry, @)

  match: (entry, matchKind)->
    pi = @pluginMap.findPlugin(entry, matchKind)
    console.log 'match:', [matchKind, entry, pi]
    #if entry.isDir()
    #  fnKey = matchKind
    #else fnKey = matchKind


class Site
  Object.defineProperties @.prototype,
    site: get: ->@

  #~ initialization

  constructor: (opt={}, plugins)->
    @meta = Object.create opt.meta||@meta||null
    @ctx = Object.create(opt.ctx||null)
    @content = qcontent.createRoot()

    @_initPlugins(opt, plugins)
    @_initWalker(opt)

  _initWalker: (opt={}) ->
    ruleset = qrules.classifier()
    @initMatchRuleset(ruleset, qrules)

    @walker = new MatchingWalker(ruleset, @tasks)
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

    #tree = @content.addTree(opt.mount)
    tree = null
    @walker.walkRootContent aPath, tree, plugins

  build: (rootPath, vars, done)->
    if typeof vars is 'function'
      done = vars; vars = null
    vars = Object.create vars || null, meta:value:@meta
    bldr = new SiteBuilder(rootPath, @content)
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
  SiteBuilder: SiteBuilder
  createSite: (opt, plugins)-> new Site(opt, plugins)
  plugins: qplugins.plugins
  createPluginMap: qplugins.createPluginMap

