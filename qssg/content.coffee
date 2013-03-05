# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##


class ContentBase
  Object.defineProperties @.prototype,
    dependencies: get: -> @deps
    deps: get: -> @deps=[]

  isContentItem: -> true
  init: (container, options)->
    if options?
      @[k]=v for k,v of options

  visit: (visitor, keyPath)->
    throw new Error("Subclass responsibility: #{@constructor.name}::visit()")

  compositeWith: (contentItem, key, container)->
    comp = new @_.ContentComposite(container, key)
    comp.addItem(key, contentItem)
    return comp


class ContentItem extends ContentBase
  kind: 'item'
  constructor: (container, @key, @renderFn)->
  visit: (visitor, keyPath=[])->
    visitor(@kind, @, keyPath.concat([@key]))


class ContentComposite extends ContentBase
  kind: 'list'
  constructor: (container, @key, @renderFn)->
    @list = []

  addItem: (key, item)->
    if not item.isContentItem()
      throw new Error("Can only add ContentItem objects")

    @list.push(item)
    return item

  compositeWith: (contentItem, key, container)->
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


class ContentTree extends ContentBase
  kind: 'tree'
  constructor: (container, @key, @renderFn)->
    @items = {}

  addItem: (key, item)->
    if not item.isContentItem()
      throw new Error("Can only add ContentItem objects")

    if (curItem = @items[key])?
      item = curItem.compositeWith(item, key, @)
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
  constructor: (key, renderFn)->
    super(null, key, renderFn)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ContentCollectionMixin
  ContentItem: ContentItem
  ContentTree: ContentTree

  newContent: (container, key, renderFn)->
    new @.ContentItem(container, key, renderFn)
  addContent: (key, renderFn, args...)->
    item = @newContent(@, key, renderFn)
    item.init(@, args...) if args.length?
    return @addItem(key, item)

  newTree: (container, key, renderFn)->
    new (@.ContentTree||@.constructor)(container, key, renderFn)
  addTree: (key, renderFn, args...)->
    item = @newTree(@, key, renderFn)
    item.init(@, args...) if args.length?
    return @addItem(key, item)

  @mixInto = (tgtClass)->
    tgt = tgtClass.prototype || tgtClass
    for k,v of @.prototype
      tgt[k] = v
    return

ContentCollectionMixin.mixInto(ContentTree)
ContentCollectionMixin.mixInto(ContentComposite)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module.exports =
  ContentBase: ContentBase
  ContentCollectionMixin: ContentCollectionMixin

  ContentItem: ContentItem
  ContentTree: ContentTree
  ContentRoot: ContentRoot
  createRoot: (renderFn)-> new ContentRoot(renderFn)

