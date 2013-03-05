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
qtree = require('./tree')
qcontent = require('./content')
{SiteBuilder} = require('./builder')

class Site
  Object.defineProperties @.prototype,
    site: get: ->@

  #~ initialization

  constructor: (opt={})->
    @meta = Object.create opt.meta||@meta||null
    @_init(opt)
    @content = qcontent.createRoot()
    @roots = []

  _init: (opt={})->
    @_initWalker(opt)
    @_initMatchRuleset(opt)
    @_initContext(opt)

  _initWalker: (opt={}) ->
    @walker = new tromp.WalkRoot(autoWalk:false)
    @walker.reject(opt.reject || /node_modules/)
    @walker.accept(opt.accept) if opt.accept?
    @walker.filter(opt.filter) if opt.filter?
    @initWalker(@walker)
    return this
  initWalker: (walker)->

  _initMatchRuleset: (opt={})->
    @matchRuleset = rs = qrules.classifier()
    @initMatchRuleset(rs, qrules)

  initMatchRuleset: (ruleset, qrules)->
    qrules.standardRuleset(ruleset)

  _initContext: (opt)->
    @ctx = Object.create(opt.ctx || @ctx)
    @plugins = @plugins.clone()

  #~ API & context

  ctx: {}
  plugins: qplugins.plugins.clone()
  walk: (path, mountPath)->
    @roots.push(root = qtree.createRoot(@, mountPath))
    return root.walk(arguments...)

  build: (rootPath, vars, done)->
    vars = Object.create vars, meta:value:@meta
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
  createSite: (opt)-> new Site(opt)
  plugins: qplugins.plugins

