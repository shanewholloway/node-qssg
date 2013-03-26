# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

fs = require 'fs'
path = require 'path'
funcQueues = require './funcQueues'

do -> exports[k]=v for k,v of funcQueues

fs = Object.create(fs)
fs.makeDirs = (aPath, mode, callback=->)->
  if typeof mode is 'function'
    callback = mode; mode = undefined
  step = (aPath, next)->
    fs.exists aPath, (exists)->
      if exists
        return next(null, false)
      step path.dirname(aPath), ->
        fs.mkdir aPath, mode, (err)->
          next(err, true)

  return step(path.resolve(aPath), callback)

exports.fs = fs


deepExtend = (hash, others...)->
  q = []
  q.push [hash,ea] for ea in others
  while q.length
    [tgt, other] = q.pop()
    for k,v of other
      d = tgt[k]
      if not d?
        tgt[k] = v
      else if d instanceof Array
        d.push.apply(d, v)
      else if typeof v is 'object'
        q.push([d,v])
  return hash
exports.deepExtend = deepExtend


createTaskTracker = ->
  self = funcQueues.closureQueue(arguments...)
  doneFns = invokeList()
  doneFns.push(self.done) if self.done?
  self.done = doneFns

  self.seed = ->
    process.nextTick self()
    return self
  self.add = (args...)->
    task = self()
    if typeof args[args.length-1] is 'function'
      task = task.wrap(args.pop())
    task.args = args if args.length?
    return task

  self.defer = (ms, callback)->
    if typeof ms is 'function'
      callback = ms; ms = null

    task = self(callback)
    if ms?
      setTimeout task, ms
    else process.nextTick task
    return task
  return self
exports.createTaskTracker = createTaskTracker


stableSort = (list, options={})->
  keyFn = options.key or (e)->e
  res = [].map.call list, (e, i)->
    return (w = keyFn(e))? and [w, i, e] or [null, i, e]
  res.sort (a,b)->
    return 1 if a[0]>b[0]
    return -1 if a[0]<b[0]
    return a[1]-b[1]
  tgt = if options.inplace then list else res
  tgt.length = res.length
  for e,i in res
    if e is undefined
      delete tgt[i]
    else tgt[i]=e.pop()
  return tgt
exports.stableSort = stableSort


# `invokeList()` creates a new function list with an `invoke()` method that
# will call each function in the list with the supplied arguments. Also
# provides function-like methods of `bind()`, `call()` and `apply()` to provide
# a callable API.

exports.invokeList = invokeList = do ->
  methods =
    bind: (args...)-> @invoke.bind(args...)
    call: (args...)-> @invoke.call(args...)
    apply: (self, args)-> @invoke.apply(self, args)

  init = (self, args...)->
    desc = {}
    for each in args
      for own k,v of each
        desc[k] = value:v
    Object.defineProperties(self, desc)
    return self

  invokeEach = (self, args, error)->
    for fn in self
      try fn(args...)
      catch err
        if self.error? then self.error(err)
        else if error? then error(err)
        else console.error(err.stack or err)

  invokeList = (self=[], error)->
    init self, methods,
      once: []
      invoke: ->
        invokeEach(self.once.splice(0), arguments, error)
        invokeEach(self, arguments, error)
        return @
  invokeList.dual = invokeList
  invokeList.create = invokeList

  invokeList.simple = (self=[], error)->
    init self, methods,
      invoke: -> invokeEach(self, arguments, error); return @

  invokeList.once = (self=[], error)->
    init self, methods,
      invoke: -> invokeEach(self.splice(0), arguments, error); return @

  invokeList.ordered = (self=[], error)->
    init self, methods,
      add: (w, fn)->
        if typeof w is 'function'
          fn = w; w = arguments[1]
        if w isnt undefined
          fn.w = w
        self.push fn
      sort: -> stableSort self, inplace:true, key:(e)-> e.w or 0
      invoke: ->
        invokeEach(self.sort(), arguments, error); return @
      iter: (iterFn)->
        q = self.sort().slice()
        return (args...)->
          while q.length and fn is undefined
            fn = q.shift()
          args.unshift fn
          iterFn(args...)

  return invokeList


`function debounce(wait, fn) {
  if (typeof wait === 'function')
    fn=wait, wait=arguments[1];
  var self, args, tid,
    dfn = function(){ fn.apply(self, args) }
  return function(){
    tid = clearTimeout(tid);
    self = this; args = arguments;
    tid = setTimeout(dfn, wait); } }
`
exports.debounce = debounce

