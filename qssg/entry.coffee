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

  _setContent: (content, contentTree)->
    Object.defineProperty @, 'content',
      value: content, enumerable: true
    if contentTree?
      Object.defineProperty content, 'tree',
        value: contentTree
    return content

  newCtxTree: (key=@name0)->
    tree = @baseTree.newTree(key)
    return @_setContent tree, tree
  addContentTree: (key=@name0)->
    tree = @baseTree.addTree(key)
    return @_setContent tree, tree

  addComposite: (key=@name0, childKey)->
    tree = @baseTree.newTree(key)
    citem = tree.getContent(childKey||key)
    @baseTree.addItem(key, citem)
    return @_setContent citem, tree

  getContent: (key=@name0)->
    return @content if @content?
    return @_setContent @baseTree.getContent(key)

  touch: (arg=true)->
    arg = @stat.mtime if arg is false
    @content.touch(arg)

  getWalkContentTree: -> @content?.tree || @baseTree

  #~ accessing content of entry

  fs: require('fs')
  readStream: (options)->
    if @_overlaySource?
      src = new stream.Stream()
      process.nextTick =>
        src.emit('data', @_overlaySource)
        src.emit('end'); src.emit('close')
      return src
    else if @isFile
      @fs.createReadStream(@src.path, options)
  read: (encoding='utf-8', callback)->
    if typeof encoding is 'function'
      callback = encoding; encoding = 'utf-8'
    if @_overlaySource?
      process.nextTick => callback(null, @_overlaySource)
    else if @isFile
      @fs.readFile(@src.path, encoding, callback)
    return
  readSync: (encoding='utf-8')->
    if @_overlaySource?
      return @_overlaySource
    else if @isFile
      return @fs.readFileSync(@src.path, encoding)
  loadModule: ->
    if @_overlaySource?
      throw new Error("`MatchEntry::loadModule()` is not currently support in overlay mode")
    require(@src.path)

  overlaySource: (source, callback)->
    return @ if not source?
    return @_overlayStream(source, callback) if source.pipe?

    self = Object.create @,
      overlaysEntry:value:@
      _source:value:source

    process.nextTick -> callback(null, self, source)
    return

  _overlayStream: (source, callback)->
    dataList = []
    source.on 'data', (data)-> dataList.push(data)
    source.on 'error', (err)-> sendAnswer?(err)
    source.on 'end', -> sendAnswer?()

    sendAnswer = (err)=>
      sendAnswer = null
      if err? then callback(err)
      else @overlaySource(dataList.join(''), callback)
    return

exports.MatchEntry = MatchEntry



class MatchingWalker extends tromp.WalkRoot
  constructor: (@site, @ruleset)->
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
    entry = new MatchEntry(entry, @baseTree, @pluginMap)
    @ruleset.matchRules(entry, @)
  _op_file: (entry)->
    entry = new MatchEntry(entry, @baseTree, @pluginMap)
    @ruleset.matchRules(entry, @)

  match: (entry, matchKind)->
    matchMethod = entry.setMatchMethod(matchKind)
    plugin = @pluginMap.findPlugin(entry)
    @site.matchEntryPlugin entry,
      plugin.bindPluginFn(matchMethod)


exports.MatchingWalker = MatchingWalker
exports.createWalker = (site, ruleset)->
  new MatchingWalker(site, ruleset)


