# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

{invokeList} = require('./util')

class Renderable
  bindRender: (renderFn)->
    Object.defineProperties @, render:value:renderFn
    return @
  bindRenderComposed: ->
    @bindRender @renderComposed
  renderTasks: ->
    if not (tasks = @_renderTasks)?
      tasks = invokeList.ordered()
      Object.defineProperties @,
        _renderTasks:value:tasks
    return tasks
  addTemplate: (tmplFn, order)->
    if typeof tmplFn isnt 'function'
      throw new Error("Content template must be a function")
    tasks = @renderTasks()
    if not tasks.tmpl?
      tasks.tmpl = invokeList.ordered()
      tasks.add 1.0, @renderTemplateFn.bind(@, tasks.tmpl)
    tasks.tmpl.add order, tmplFn
    return @

  renderTemplateFn: (templates, source, vars, answerFn)->
    tmplFn = templates.sort().slice(-1).pop()
    vars = Object.create vars, content:value:source
    tmplFn(vars, answerFn)

  renderComposed: (vars, answerFn)->
    vars.ctx = @ctx
    try
      stepFn = @_renderTasks.iter (renderFn, err, src)->
        if not err? and renderFn isnt undefined
          try renderFn(src, vars, stepFn)
          catch err then answerFn(err)
        else answerFn(err, src)
      stepFn()
    catch err
      answerFn(err)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentBaseNode extends Renderable
  isContentNode: true
  init: (parent)->
    Object.defineProperties @, parent:value:parent
    @meta = {}
    @ctx = @initCtx(parent?.ctx, parent)

  updateMetaFromEntry: (entry)->
    @meta.entry = entry
    @meta.srcPath = entry.srcPath

  initCtx: (ctx_next)-> ctx_next || @pushCtx()
  pushCtx: (ctx_next)->
    if not ctx_next?
      return {tmpl:{}}
    tmpl = Object.create(ctx_next.tmpl||={})
    return Object.create ctx_next,
      tmpl:{value:tmpl}, ctx_next:{value:ctx_next}

  visit: (visitor, keyPath)->
    throw new Error("Subclass responsibility: #{@constructor.name}::visit()")

  compositeWith: (key, contentItem, parent)->
    comp = new ContentComposite(parent, key)
    comp.addItem(@name, @)
    comp.addItem(key, contentItem)
    return comp

  touch: (arg=true)->
    if arg is 0
      delete @mtime
    else if arg is true
      @mtime = new Date()
    else
      arg = Math.max(@mtime||0, arg||0)
      @mtime = new Date(arg)
    return @mtime

class ContentItem extends ContentBaseNode
  kind: 'item'
  constructor: (parent, @name)->
    @init(parent)

  initCtx: (ctx_next)-> ctx_next
  visit: (visitor, keyPath=[])->
    visitor(@kind, @, keyPath.concat([@name]))


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentComposite extends ContentBaseNode
  kind: 'composite'
  constructor: (parent, @name)->
    @list = []
    @init(parent)

  addItem: (key, item)->
    if not item.isContentNode
      throw new Error("Can only add ContentItem objects")

    @list.push(item)
    return item

  compositeWith: (key, contentItem, parent)->
    @list.push(contentItem)
    return @

  visit: (visitor, keyPath=[])->
    res = visitor(@kind, @, keyPath.slice())
    if res is false
      # curtail walking items map
    else @visitList(visitor, keyPath)

  visitList: (visitor, keyPath=[])->
    for each in @list
      each.visit(visitor, keyPath)
    return true


class ContentRoot extends ContentComposite
  kind: 'root'
  constructor: (key)-> super(null, key)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentTreeNode extends ContentBaseNode
  kind: 'tree'
  constructor: (parent, @name)->
    @items = {}
    @init(parent)
    if not @name
      throw new Error("Key must be valid #{@}")

  addItem: (key, item)->
    if not item.isContentNode
      throw new Error("Can only add ContentNode objects")

    if (curItem = @items[key])?
      item = curItem.compositeWith(key, item, @)
    @items[key] = item
    return item
  getItem: (key)-> @items[key]

  visit: (visitor, keyPath=[])->
    keyPath = keyPath.concat([@name])
    res = visitor(@kind, @, keyPath.slice())
    if res is false
      # curtail walking items map
    else @visitItems(visitor, keyPath)

  visitItems: (visitor, keyPath=[])->
    for key, each of @items
      each.visit(visitor, keyPath)
    return true

class ContentTree extends ContentTreeNode
  isContentTree: true
  initCtx: (ctx_next, parent)->
    if parent?.isContentTree
      return @pushCtx(ctx_next)
    return super(ctx_next, parent)

class CtxTree extends ContentTreeNode
  kind: 'ctx_tree'
  isCtxTree: true
  initCtx: (ctx_parent)->
    if ctx_parent?
      ctx = @pushCtx(ctx_parent[@name])
      return ctx_parent[@name] = ctx
    else return @pushCtx()

  adaptMatchKind: (matchKind)-> 'context'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentCollectionMixin
  ContentItem: ContentItem
  ContentTree: ContentTree
  CtxTree: CtxTree

  newContentEx: (parent, key)->
    new @.ContentItem(parent, key)
  newContent: (key)->
    @newContentEx(@, key)
  addContent: (key)->
    @addItem key, @newContentEx(@, key)
  getContent: (key)->
    if not (item = @getItem?(key))?
      item = @addContent(key)
    return item

  newTreeEx: (parent, key)->
    new @.ContentTree(parent, key)
  newTree: (key)->
    @newTreeEx(@, key)
  addTree: (key)->
    @addItem key, @newTreeEx(@, key)

  newCtxTreeEx: (parent, key)->
    new @.CtxTree(parent, key)
  newCtxTree: (key)->
    @newCtxTreeEx(@, key)

  @mixInto = (tgtClass)->
    tgt = tgtClass.prototype || tgtClass
    for k,v of @.prototype
      tgt[k] = v
    return

ContentCollectionMixin.mixInto(ContentTree)
ContentCollectionMixin.mixInto(ContentComposite)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module.exports =
  ContentBaseNode: ContentBaseNode
  ContentCollectionMixin: ContentCollectionMixin

  ContentItem: ContentItem
  ContentTree: ContentTree
  ContentRoot: ContentRoot
  createRoot: -> new ContentRoot()

