# -*- coding: utf-8 -*- vim: set ts=2 sw=2 expandtab
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##
##~ Copyright (C) 2002-2013  TechGame Networks, LLC.              ##
##~                                                               ##
##~ This library is free software; you can redistribute it        ##
##~ and/or modify it under the terms of the MIT style License as  ##
##~ found in the LICENSE file included with this distribution.    ##
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~##

exports.pluginTypes = pluginTypes = {}

class ComposedCommonPlugin
  kinds: ''
  registerPluginOn: (pluginMap)->
    pluginMap.addPluginAt '&'+@kind

  init: (opt)-> @initOptions(opt) if opt?
  initOptions: (opt)->
    if opt?
      for own k,v of opt
        @[k] = v
    return @

  inspect: -> "«#{@constructor.name}»"
  toString: -> @inspect()

  composePlugin: (pi, entry)->
    Object.create @, pi:value:pi

exports.ComposedCommonPlugin = ComposedCommonPlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ComposedFilePlugin extends ComposedCommonPlugin
  isFileKindPlugin: true

  simple: (entry, callback)->
    @pi.bindRender(entry, callback)
  composite: (entry, callback)->
    @pi.bindRender(entry, callback)
  context: (entry, callback)->
    @pi.bindContext(entry, callback)

exports.ComposedFilePlugin = ComposedFilePlugin

pluginTypes.composed_file = ComposedFilePlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ComposedDirPlugin extends ComposedCommonPlugin
  isDirKindPlugin: true

  simpleDir: (entry, callback)->
    @pi.contentDir(entry, callback)
  compositeDir: (entry, callback)->
    @pi.contentDir(entry, callback)
  contextDir: (entry, callback)->
    @pi.bindContextDir(entry, callback)

exports.ComposedDirPlugin = ComposedDirPlugin
pluginTypes.composed_dir = ComposedDirPlugin

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class ComposedPlugin extends ComposedCommonPlugin
  isFileKindPlugin: true
  isDirKindPlugin: true

  simple: ComposedFilePlugin::simple
  composite: ComposedFilePlugin::composite
  context: ComposedFilePlugin::context
  simpleDir: ComposedDirPlugin::simpleDir
  compositeDir: ComposedDirPlugin::compositeDir
  contextDir: ComposedDirPlugin::contextDir

exports.ComposedPlugin = ComposedPlugin
pluginTypes.composed = ComposedPlugin

