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
  fsTaskQueue: qutil.taskQueue(35)
  constructor: (rootPath, @contentTree)->
    @rootPath = path.resolve(rootPath)
    @cwd = path.resolve('.')

  build: (vars, doneBuildFn)->
    if typeof vars is 'function'
      doneBuildFn = vars; vars = null

    rootOutput = Object.create null,
      rootPath: value: @rootPath, enumerable: true
    rootVars = Object.create vars||null,
      output: value: rootOutput

    trackerMap = {}
    fsTasks = qutil.invokeList.ordered()
    dirTasks = qutil.createTaskTracker =>
      @fsTaskQueue.extend fsTasks.sort(); fsTasks = null
    tasks = qutil.createTaskTracker qutil.debounce 100, ->
      clearInterval(tidUpdate); doneBuildFn()
    tidUpdate = setInterval @logTasksUpdate.bind(@, tasks, trackerMap), @msTasksUpdate||2000

    logStarted = @logStarted.bind(@)
    logUnchanged = @logUnchanged.bind(@)
    @contentTree.visit (vkind, citem, keyPath)=>
      relPath = keyPath.join('/')
      fullPath = path.resolve(@rootPath, relPath)
      if vkind is 'tree'
        @fs.makeDirs fullPath, dirTasks()

      if not citem.render?
        return

      output = Object.create rootOutput,
        vkind: value: vkind
        relPath: value: relPath, enumerable: true
        fullPath: value: fullPath
        content: value: citem

      vars = Object.create rootVars,
        output: value: output, enumerable: true

      fsTasks.push (taskDone)=>
        @fs.stat output.fullPath, taskDone.wrap (err, stat)=>
          if stat?
            output.mtime = stat.mtime
            if citem.mtime? and citem.mtime > stat.mtime
              return logUnchanged(output)
          logStarted(output)
          renderAnswer = tasks =>
            delete trackerMap[relPath]
            @renderAnswerEx(output, arguments...)
          trackerMap[relPath] = renderAnswer
          citem.render(vars, renderAnswer)

      return true

  fs: qutil.fs
  renderAnswerEx: (rx, err, what)->
    if err? and not @logError(err, rx)
      return

    if what?
      mtime = rx.content?.mtime
      if mtime? and rx.mtime and mtime<=rx.mtime
        @logUnchanged(rx)
      else
        @fsTaskQueue.do =>
          if what.pipe?
            what.pipe(@fs.createWriteStream(rx.fullPath))
          else @fs.writeFile(rx.fullPath, what)
          @logChanged(rx)
    return

  logPathsFor: (rx)->
    dst: path.relative @cwd, rx.relPath
    src: path.relative @cwd, rx.content?.entry?.srcPath || rx.relPath
  logStarted: (rx)->
    #paths = @logPathsFor(rx)
    #console.error "start['#{paths.src}'] -- '#{paths.dst}'"
    return
  logError: (err, rx)->
    paths = @logPathsFor(rx)
    console.error "ERROR['#{paths.src}'] :: #{err}"
    return
  logChanged: (rx)->
    paths = @logPathsFor(rx)
    console.error "WRITE['#{paths.src}'] -- '#{paths.dst}'"
    return
  logUnchanged: (rx)->
    #dstPath = path.relative @cwd, rx.relPath
    #srcPath = path.relative @cwd, rx.content?.entry?.srcPath || rx.relPath
    #console.error "unchanged['#{srcPath}'] -- '#{dstPath}'"
    return

  logTasksUpdate: (tasks, trackerMap)->
    console.warn "tasks active: #{tasks.active} waiting on: #{inspect(Object.keys(trackerMap))}"

exports.SiteBuilder = SiteBuilder
exports.createBuilder = (rootPath, content)->
  new SiteBuilder(rootPath, content)

