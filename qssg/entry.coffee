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

    name: get:->
      ext = @ext.join('.')
      @name0 + (ext && "."+ext or '')

  isFile: -> @src.isFile()
  isDirectory: -> @src.isDirectory()
  isWalkable: -> @src.isWalkable(arguments...)
  walk: -> @src.walk(arguments...)

  constructor: (walkEntry, baseTree, pluginMap)->
    ext = walkEntry.name.split('.')
    name0 = ext.shift()

    Object.defineProperties @,
      src: value: walkEntry
      srcName0: value: name0
      srcExt: get:-> ext.slice()
      stat: value: walkEntry.stat
      baseTree: value: baseTree
      pluginMap: value: pluginMap

    @name0 = name0
    @ext = ext.slice()

  toJSON: -> {path:@relPath, src:{path:@relPath, mode:@mode}}
  inspect: -> "[#{@constructor.name} #{@mode}:'#{@relPath}' src:'#{@srcRelPath}']"
  toString: -> @inspect()

  walkPath: -> @src.path
  walk: ->
    if @isWalkable()
      @node.root.walk(@, @node.target)

  newContentTree: (key=@name0)->
    return @contentTree = @baseTree.newTree(key)
  addContentTree: (key=@name0)->
    return @contentTree = @baseTree.addTree(key)

  touch: (arg)->
    if arg is null
      delete @mtime
    else
      arg = new Date() if arg is true
      @mtime = new Date(Math.max(@mtime||0, arg||0, @stat.mtime))
    return @mtime

  #~ accessing content of entry

  fs: require('fs')
  readStream: (options)->
    if @isFile
      @fs.createReadStream(@src.path, options)
  read: (encoding='utf-8', callback)->
    if typeof encoding is 'function'
      callback = encoding; encoding = 'utf-8'
    if @isFile
      return @fs.readFile(@src.path, encoding, callback)
  readSync: (encoding='utf-8')->
    if @isFile
      return @fs.readFileSync(@src.path, encoding)
  loadModule: -> require(@src.path)

  OverlayMethods:
    read: (encoding='utf-8', callback)->
      if typeof encoding is 'function'
        callback = encoding; encoding = 'utf-8'
      process.nextTick => callback(null, @_source)
      return
    readSync: (encoding='utf-8')-> @_source
    readStream: (options)->
      src = new stream.Stream()
      process.nextTick =>
        src.emit('data', @_source)
        src.emit('end'); ee.emit('close')
      return ee

  overlaySource: (source, overlayReady)->
    return @ if not source?
    return @_overlayStream(source, overlayReady) if source.pipe?

    self = Object.create @,
      overlaysEntry:value:@
      _source:value:source

    for k,v of @OverlayMethods
      self[k] = v

    process.nextTick ->
      overlayReady(null, self, source)
    return

  _overlayStream: (source, overlayReady)->
    dataList = []
    source.on 'data', (data)-> dataList.push(data)
    source.on 'error', (err)-> sendAnswer(err)
    source.on 'end', -> sendAnswer()

    sendAnswer = (err)=>
      sendAnswer = null
      if not err?
        @overlaySource(dataList.join(''), overlayReady)
      else overlayReady(err)
    return

exports.MatchEntry = MatchEntry



class MatchingWalker extends tromp.WalkRoot
  constructor: (@site, @ruleset)->
    super(autoWalk: false)
    Object.defineProperty @, '_self_', value:@

  instance: (content, pluginMap)->
    Object.create @_self_,
      content:{value:content}
      pluginMap:{value:pluginMap||@pluginMap}

  walkListing: (listing)->
    if (entry = listing.node.entry)?
      if not (tree = entry.contentTree)?
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
    @site.matchEntryPlugin(pi, entry, matchKind)


exports.MatchingWalker = MatchingWalker
exports.createWalker = (site, ruleset)->
  new MatchingWalker(site, ruleset)


