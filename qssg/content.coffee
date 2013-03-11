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


class ContentItem extends ContentBaseNode
  kind: 'item'
  constructor: (container, @key, @entry)->
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
  constructor: (container, @key, @entry)->
    @items = {}
    @init(container)

  addItem: (key, item)->
    if not item.isContentNode
      throw new Error("Can only add ContentNode objects")

    if (curItem = @items[key])?
      item = curItem.compositeWith(key, item, @)
    @items[key] = item
    return item

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

    ctx_next = ctx_parent[@entry.name0]
    ctx = Object.create ctx_next||null,
      ctx_next:value:ctx_next
    return ctx_parent[@entry.name0] = ctx

  adaptMatchKind: (matchKind, entry)-> 'context'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentCollectionMixin
  ContentItem: ContentItem
  ContentTree: ContentTree
  CtxTree: CtxTree

  initCtx: (ctx_next)->
    Object.create ctx_next||null,
      ctx_next:value:ctx_next

  newContentEx: (container, key, entry)->
    new @.ContentItem(container, key, entry)
  newContent: (key, entry)->
    @newContentEx(@, key, entry)
  addContent: (key, entry)->
    @addItem key, @newContentEx(@, key, entry)

  newTreeEx: (container, key, entry)->
    new @.ContentTree(container, key, entry)
  newTree: (key, entry)->
    @newTreeEx(@, key, entry)
  addTree: (key, entry)->
    @addItem key, @newTreeEx(@, key, entry)

  newCtxTreeEx: (container, key, entry)->
    new @.CtxTree(container, key, entry)
  newCtxTree: (key, entry)->
    @newCtxTreeEx(@, key, entry)

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

