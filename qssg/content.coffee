# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##


class ContentBaseNode
  Object.defineProperties @.prototype,
    dependencies: get: -> @deps
    deps: get: -> @deps=[]

  isContentNode: true
  init: (container)->
    @ctx = @initCtx(container?.ctx)

  initCtx: (ctx_next)-> ctx_next || {}
  visit: (visitor, keyPath)->
    throw new Error("Subclass responsibility: #{@constructor.name}::visit()")

  renderFn: (vars, answerFn)-> answerFn()

  compositeWith: (key, contentItem, container)->
    comp = new ContentComposite(container, key)
    comp.addItem(@key, @)
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
  constructor: (container, @key)->
    @init(container)

  initCtx: (ctx_next)-> ctx_next
  visit: (visitor, keyPath=[])->
    visitor(@kind, @, keyPath.concat([@key]))


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentComposite extends ContentBaseNode
  kind: 'composite'
  constructor: (container, @key)->
    @list = []
    @init(container)

  addItem: (key, item)->
    if not item.isContentNode
      throw new Error("Can only add ContentItem objects")

    @list.push(item)
    return item

  compositeWith: (key, contentItem, container)->
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

class ContentTree extends ContentBaseNode
  kind: 'tree'
  constructor: (container, @key)->
    @items = {}
    @init(container)

  addItem: (key, item)->
    if not item.isContentNode
      throw new Error("Can only add ContentNode objects")

    if (curItem = @items[key])?
      item = curItem.compositeWith(key, item, @)
    @items[key] = item
    return item
  getItem: (key)-> @items[key]

  visit: (visitor, keyPath=[])->
    keyPath = keyPath.concat([@key])
    res = visitor(@kind, @, keyPath.slice())
    if res is false
      # curtail walking items map
    else @visitItems(visitor, keyPath)

  visitItems: (visitor, keyPath=[])->
    for key, each of @items
      each.visit(visitor, keyPath)
    return true


class CtxTree extends ContentTree
  kind: 'ctx_tree'
  isCtxTree: true
  initCtx: (ctx_parent)->
    if not ctx_parent?
      return {}

    ctx_next = ctx_parent[@key]
    ctx = Object.create ctx_next||null,
      ctx_next:value:ctx_next
    return ctx_parent[@key] = ctx

  adaptMatchKind: (matchKind)-> 'context'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentCollectionMixin
  ContentItem: ContentItem
  ContentTree: ContentTree
  CtxTree: CtxTree

  initCtx: (ctx_next)->
    Object.create ctx_next||null,
      ctx_next:value:ctx_next

  newContentEx: (container, key)->
    new @.ContentItem(container, key)
  newContent: (key)->
    @newContentEx(@, key)
  addContent: (key)->
    @addItem key, @newContentEx(@, key)
  getContent: (key)->
    if not (item = @getItem?(key))?
      item = @addContent(key)
    return item

  newTreeEx: (container, key)->
    new @.ContentTree(container, key)
  newTree: (key)->
    @newTreeEx(@, key)
  addTree: (key)->
    @addItem key, @newTreeEx(@, key)

  newCtxTreeEx: (container, key)->
    new @.CtxTree(container, key)
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

