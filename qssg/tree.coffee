# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

path = require('path')

qrules = require('./rules')
qutil = require('./util')

class BasicTree
  Object.defineProperties @.prototype,
    walker: get:-> @site.walker
    plugins: get:-> @parent.plugins
    matchRuleset: get:-> @parent.matchRuleset

  #~ initialization

  isTree: -> true
  constructor: (parent, entry, opt={})->
    @_init(parent, entry, opt)

  initTreeContext: ->
    @ctx = @initCtx(@parent?.ctx)
    @content = @createContentTree()

  initCtx: (ctx)-> Object.create(ctx || null)
  extendVars: (vars={})->
    vars.ctx = @ctx
    return vars

  initRuleset: (qrules)-> @matchRuleset = @matchRuleset
  initEntry: (entry)-> @walk(@entry) if (@entry)?
  initPlugins: (plugins)->
    if plugins?
      Object.defineProperty @, 'plugins',
        value: @plugins.clone().merge(plugins)

  _init: (@parent, entry, opt={})->
    @site = @parent.site
    if entry?.relPath?
      @entry = entry
    else if opt.mount
      @mountPoint = opt.mount.toString()

    @tasks = qutil.createTaskTracker()
    @initRuleset(qrules)
    @initPlugins(opt.plugins)
    @initTreeContext()
    @initEntry()

  #~ Utils

  inspect: ->
    if @entry?
      "[#{@constructor.name} at:'./#{@entry.srcRelPath}']"
    else "[#{@constructor.name} at:-]"
  toString: -> @inspect()


  #~ walk & classify protocol

  walk: (pathOrEntry)-> @walker.walk(pathOrEntry, @)
  walkNotify: (walkKey, entry)->
    if walkKey is 'entry'
      @matchRuleset.matchRules(entry, @)
    if walkKey is 'listed'
      @tasks.defer 10, -> # add a task so empty directories complete
    return true
  match: (entry, matchKey)-> @_match_doesNotUnderstand(entry, matchKey)
  _match_doesNotUnderstand: (entry, matchKey)->
    console.log "#{@}::match() handle {entry:'#{entry.relPath}', matchKey:'#{matchKey}'}"

  #~ Task API

  setCtxVar: (key, value)-> @ctx[key] = value
  taskCtxVar: (entry)->
    @tasks.add entry, (err, value)=>
      if value is not undefined
        @setCtxVar(entry.name0, value)

  taskEvaluate: (entry)-> @tasks.add entry, null
  taskComposite: (entry)-> @tasks.add entry, null
  taskCompositeFile: (entry)-> @tasks.add entry, null
  taskSubTree: (entry, tree)-> @tasks.add entry, null
  taskCtxTree: (entry, tree)-> @tasks.add entry, null

  tasksDone: (callback)->
    if @tasks.isDone()
      callback(@tasks, @tasks.completed)
    else @tasks.done.once.push(callback)
    return @

  isDone: -> @tasks.isDone()

  #~ Content API

  keyFromEntry: (srcEntry, dstEntry)->
    srcPath = srcEntry?.srcRelPath or @mountPoint or '.'
    path.relative(srcPath, dstEntry?.relPath)
  asKey: (dstEntry)->
    if dstEntry?
      return @keyFromEntry(@entry, dstEntry)
    else if @entry?
      return @keyFromEntry(@parent.entry, @entry)
    else return @mountPoint or '.'

  addContent: (entry, plugin)->
    if plugin.rename?
      entry = plugin.rename(entry, @)

    task = @tasks.add entry, plugin,
      @addContentFn.bind(@, {entry:entry, plugin:plugin})
    if not plugin.bindContent?
      renderFn = (vars, answerFn)=>
        plugin.content(entry, @, vars, answerFn)
      task(null, renderFn)
    else
      plugin.bindContent(entry, @, task)

  addContentFn: (obj, err, renderFn)->
    if typeof err is 'function' and not renderFn?
      renderFn = err; err = null
    @content.addContent(@asKey(obj.entry), renderFn, obj) if not err?

  createContentTree: -> @addParentContentTree()
  addParentContentTree: (renderFn=@renderTreeFn.bind(@))->
    @parent.content.addTree(@asKey(), renderFn, {tree:@, entry:@entry})

  renderTreeFn: (vars, answerFn)->
    @tasksDone -> answerFn(null)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~ BasicTree with self-dispatching match protocol
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class BasicTreeDispatch extends BasicTree
  #~ self dispatch protocol

  findPlugin: (entry, matchKey)->
    @plugins.findPlugin(entry, matchKey)

  findDisp: (matchKey, mode)->
    return @["match_#{matchKey}_#{mode}"] or @["match_#{matchKey}"] or @["match_#{mode}"]

  _match_doesNotUnderstand: (entry, matchKey)->
    console.log "'#{entry.relPath}' from #{@} as: match_#{matchKey}_#{entry.mode}()"

  match: (entry, matchKey)->
    mode = entry.mode
    handleFn = @findDisp(matchKey, entry.mode)
    @tasks.defer =>
      if handleFn?
        plugin = @findPlugin(entry, matchKey)
        return handleFn.call(@, entry, plugin)
      return @_match_doesNotUnderstand(entry, matchKey)



  if 0 # mode based dispatch api
    match_file: (entry, plugin)->
    match_dir: (entry, plugin)->



  if 0 # match simple dispatch api
    match_simple: (entry, plugin)->
    match_simple_dir: (entry, plugin)->
    match_simple_file: (entry, plugin)->

  # standard impl. of simple dispatches
  newSubTree: (entry)-> new @.constructor(@, entry)
  match_simple_dir: (entry, plugin)->
    tree = @newSubTree(entry)
    plugin.subTree?(entry, tree, @, @taskSubTree(entry, tree)) if tree?
    return
  match_simple_file: (entry, plugin)->
    @addContent(entry, plugin)
    return



  if 0 # match evaluate dispatch api
    match_evaluate: (entry, plugin)->
    match_evaluate_dir: (entry, plugin)->
    match_evaluate_file: (entry, plugin)->

  # standard impl. of evaluate dispatch
  match_evaluate: (entry, plugin)->
    plugin.evaluate(entry, @, @taskEvaluate(entry))
    return



  if 0 # match context dispatch api
    match_context: (entry, plugin)->
    match_context_dir: (entry, plugin)->
    match_context_file: (entry, plugin)->

  # standard impl. of context dispatches
  newCtxTree: (entry)-> new ContextTree(@, entry)
  match_context_dir: (entry, plugin)->
    tree = @newCtxTree(entry)
    plugin.ctxTree?(entry, tree, @, @taskCtxTree(entry, tree)) if tree?
    return
  match_context_file: (entry, plugin)->
    plugin.variable(entry, @, @taskCtxVar(entry))
    return


  if 0 # match composite dispatch api
    match_composite: (entry, plugin)->
    match_composite_dir: (entry, plugin)->
    match_composite_file: (entry, plugin)->

  newCompositeTree: (entry)-> new CompositeTree(@, entry)
  # standard impl. of composite dispatches
  match_composite_dir: (entry, plugin)->
    plugin.composite(entry, @, @taskComposite(entry))
    return
  match_composite_file: (entry, plugin)->
    plugin.compositeFile(entry, @, @taskCompositeFile(entry))
    return



class Tree extends BasicTreeDispatch


class CompositeTree extends Tree
  createContentTree: ->
    if @entry.ext
      @parent.addContentFn {tree:@, entry:@entry}, @renderCompositeFile.bind(@)
      return @parent.content.newTree()
    else return @addParentContentTree()

  renderCompositeFile: (vars, answerFn)->
    item = @content.items[@entry.name]
    if item?
      return item.renderFn(vars, answerFn)

    else
      entryPath = path.join(@entry.srcRelPath, @entry.name)
      err = "Composite could not find renderer for '#{entryPath}'"
      return answerFn(err)


class ContextTree extends BasicTreeDispatch
  ctxKey: (entry=@entry)-> entry.name0
  initCtx: (ctx, entry)->
    Object.create(ctx[@ctxKey(entry)] || null)

  match_simple_file: (entry, plugin)->
    plugin.variable entry, @, @taskCtxVar(entry)

  createContentTree: ->
    return @parent.content.newTree()


module.exports =
  BasicTree: BasicTree
  BasicTreeDispatch: BasicTreeDispatch

  Tree: Tree
  CompositeTree: CompositeTree
  ContextTree: ContextTree
  createRoot: (site, opt)->
    new Tree(site, null, opt)

