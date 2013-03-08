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

  isContentNode: -> true
  init: (container, options)->
    @ctx = @initCtx(container?.ctx)
    if options?
      @[k]=v for k,v of options

  initCtx: (ctx)-> ctx || {}

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
  constructor: (container, @key)->
  visit: (visitor, keyPath=[])->
    visitor(@kind, @, keyPath.concat([@key]))



class ContentComposite extends ContentBaseNode
  kind: 'composite'
  constructor: (container, @key)->
    @list = []

  addItem: (key, item)->
    if not item.isContentNode()
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


class ContentTree extends ContentBaseNode
  kind: 'tree'
  constructor: (container, @key)->
    @items = {}

  addItem: (key, item)->
    if not item.isContentNode()
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


class ContentRoot extends ContentComposite
  kind: 'root'
  constructor: (key)-> super(null, key)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentCollectionMixin
  ContentItem: ContentItem
  ContentTree: ContentTree

  initCtx: (ctx)-> Object.create(ctx||null)
  newContentEx: (container, key, argsEx)->
    item = new @.ContentItem(container, key)
    item.init(@, argsEx...) if argsEx?
    return item
  newContent: (key, args...)->
    @newContentEx(@, key, args)
  addContent: (key, args...)->
    @addItem key, @newContentEx(@, key, args)

  newTreeEx: (container, key, argsEx)->
    item = new @.ContentTree(container, key)
    item.init(@, argsEx...) if argsEx.length?
    return item
  newTree: (container, key, args...)->
    @newTree(@, key, args)
  addTree: (key, args...)->
    @addItem key, @newTree(@, key, args)

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

