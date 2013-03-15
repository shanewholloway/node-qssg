# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

stream = require('stream')
tromp = require('tromp')


class MatchEntry
  Object.defineProperties @.prototype,
    srcName: get:-> @src.name
    srcPath: get:-> @src.path
    srcRelPath: get:-> @src.relPath
    mode: get:-> @src.mode
    stat: get:-> @src.stat

    path: get: -> @src.node.resolve(@name)
    relPath: get: -> @src.node.relative @path
    rootPath: get: -> @src.node.rootPath
    parentEntry: get: -> @src.node.entry

    ctx: get: -> @content?.ctx || @baseTree.ctx
    name: get:->
      ext = @ext.join('.')
      @name0 + (ext && "."+ext or '')

  isFile: -> @src.isFile()
  isDirectory: -> @src.isDirectory()

  constructor: (walkEntry, baseTree, pluginMap)->
    @ext = walkEntry.name.split('.')
    @name0 = @ext.shift()

    Object.defineProperties @,
      src: value: walkEntry
      srcExt: value: @ext.slice()
      baseTree: value: baseTree
      pluginMap: value: pluginMap

  setMatchMethod: (matchKind)->
    if @baseTree.adaptMatchKind?
      matchKind = @baseTree.adaptMatchKind(matchKind, entry)
    if @isDirectory()
      return @matchMethod = matchKind + 'Dir'
    else return @matchMethod = matchKind

  toJSON: -> {path:@relPath, src:{path:@relPath, mode:@mode}}
  inspect: -> "[#{@constructor.name} #{@mode}:'#{@relPath}' src:'#{@srcRelPath}']"
  toString: -> @inspect()

  walk: ->
    if @src.isWalkable()
      @src.node.root.walk(@, @src.node.target)
  isWalkable: -> @src.isWalkable(arguments...)
  walkPath: -> @src.path

  setCtxValue: (value)->
    if value isnt undefined
      @ctx[@name0] = value
  setCtxTemplate: (tmplFn)->
    if typeof tmplFn is 'function'
      @ctx.tmpl[@name0] = tmplFn
    else if tmplFn isnt undefined
      throw new Error("setCtxTemplate must be called with a template function ")

  #~ content/output related

  _setContent: (content, tree)->
    if tree? # add the tree to the *content*
      Object.defineProperty content, 'tree', value:tree
    Object.defineProperty @, 'content',
      value:content, enumerable:true
    return content

  newCtxTree: (key=@name)->
    tree = @baseTree.newTree(key)
    return @_setContent tree, tree
  addContentTree: (key=@name)->
    tree = @baseTree.addTree(key)
    return @_setContent tree, tree

  addComposite: (key=@name, childKey)->
    tree = @baseTree.newTree(key)
    citem = tree.getContent(childKey||key)
    @baseTree.addItem(key, citem)
    return @_setContent citem, tree

  getContent: (key=@name)->
    return @content if @content?
    return @_setContent @baseTree.getContent(key)
  bindContent: (key=@name)->
    content = @getContent(@name)
    content.updateMetaFromEntry(@)
    return content

  getWalkContentTree: -> @content?.tree || @baseTree

  #~ accessing content of entry

  fs: require('fs')
  readStream: (options)->
    if @isFile
      @fs.createReadStream(@src.path, options)
  read: (encoding='utf-8', callback)->
    if typeof encoding is 'function'
      callback = encoding; encoding = 'utf-8'
    if @isFile
      @fs.readFile(@src.path, encoding, callback)
    return
  readSync: (encoding='utf-8')->
    if @isFile
      return @fs.readFileSync(@src.path, encoding)
  loadModule: ->
    require(@src.path)

exports.MatchEntry = MatchEntry



class MatchingWalker extends tromp.WalkRoot
  constructor: (@site, @ruleset, @history={})->
    super(autoWalk: false)
    Object.defineProperty @, '_self_', value:@

  instance: (baseTree, pluginMap)->
    Object.create @_self_,
      baseTree:{value:baseTree}
      pluginMap:{value:pluginMap||@pluginMap}

  walkListing: (listing)->
    if (entry = listing.node.entry)?.isDirectory()
      return @instance entry.getWalkContentTree(), entry.pluginMap
    return @

  walkRootContent: (aPath, baseTree, pluginMap)->
    @instance(baseTree, pluginMap).walk(aPath)

  walkNotify: (op, args...)->
    @["_op_"+op]?.apply(@, args)
  _op_dir: (entry)->
    c = @history[entry.path] || 0
    entry = new MatchEntry(entry, @baseTree, @pluginMap)
    if c is 0 or @site.rewalkEntry(entry, c)
      @history[entry.path] = c+1
      @ruleset.matchRules(entry, @)
  _op_file: (entry)->
    entry = new MatchEntry(entry, @baseTree, @pluginMap)
    @ruleset.matchRules(entry, @)

  match: (entry, matchKind)->
    try
      matchMethod = entry.setMatchMethod(matchKind)
      plugin = @pluginMap.findPlugin(entry)
      @site.matchEntryPlugin entry,
        plugin.bindPluginFn(matchMethod)
    catch err
      console.warn(entry)
      console.warn(err.stack or err)
      console.warn('')


exports.MatchingWalker = MatchingWalker
exports.createWalker = (site, ruleset)->
  new MatchingWalker(site, ruleset)


