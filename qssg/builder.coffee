# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

path = require('path')
qutil = require('./util')
{inspect} = require('util')

class SiteBuilder
  constructor: (rootPath, @contentTree)->
    @rootPath = path.resolve(rootPath)
    @cwd = path.resolve('.')

  build: (vars, done)->
    if typeof vars is 'function'
      done = vars; vars = null

    rootPath = @rootPath
    rootOutput = Object.create null,
      rootPath: value: @rootPath, enumerable: true
    vars = Object.create vars||null,
      output: value: rootOutput

    trackerMap = {}

    fnList = qutil.functionList.once()
    dirTasks = qutil.createTaskTracker(-> fnList.invoke())
    tasks = qutil.createTaskTracker ->
      clearInterval(tidUpdate)
      done()
    tidUpdate = setInterval(->
        console.warn "tasks active: #{tasks.active} waiting on: #{inspect(Object.keys(trackerMap))}"
      2000)

    logStarted = @logStarted.bind(@)
    @contentTree.visit (vkind, contentItem, keyPath)=>
      return true if not contentItem.renderFn?

      relPath = keyPath.join('/')
      fullPath = path.resolve(@rootPath, relPath)
      if vkind is 'tree'
        @fs.makeDirs fullPath, dirTasks()

      obj = Object.create rootOutput,
        vkind: value: vkind
        relPath: value: relPath, enumerable: true
        fullPath: value: fullPath
        contentItem: value: contentItem

      objVars = Object.create vars,
        output: value: obj, enumerable: true

      renderAnswer = tasks =>
        delete trackerMap[relPath]
        @renderAnswerEx(obj, arguments...)
      trackerMap[relPath] = renderAnswer

      fnList.push ->
        logStarted(obj)
        contentItem.renderFn(objVars, renderAnswer)

      return true

  fs: qutil.fs
  renderAnswerEx: (rx, err, what)->
    if err? and not @logError(err, rx)
      return

    if what?
      mtime = rx.contentItem.entry?.mtime
      @fs.isChanged rx.fullPath, mtime, (changed)=>
        if changed
          if what.pipe?
            what.pipe(@fs.createWriteStream(rx.fullPath))
          else
            @fs.writeFile(rx.fullPath, what)
          @logChanged(rx)
        else @logUnchanged(rx)
    return

  logStarted: (rx)->
    #console.error "start['#{path.relative(@cwd, rx.fullPath)}']"
    return
  logError: (err, rx)->
    console.error "ERROR['#{path.relative(@cwd, rx.fullPath)}'] :: #{err}"
    return
  logChanged: (rx)->
    console.error "WRITE['#{path.relative(@cwd, rx.fullPath)}']"
    return
  logUnchanged: (rx)->
    #console.error "unchanged ['#{path.relative(@cwd, rx.fullPath)}']"
    return

exports.SiteBuilder = SiteBuilder

