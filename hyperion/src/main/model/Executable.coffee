###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###
'use strict'

fs = require 'fs'
path = require 'path'
async = require 'async'
coffee = require 'coffee-script'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'
utils = require '../utils'

root = utils.confKey 'executable.source'
compiledRoot = utils.confKey 'executable.target'
encoding = utils.confKey 'executable.encoding', 'utf8'
ext = utils.confKey 'executable.extension','.coffee'

utils.enforceFolderSync root, false, logger


# hashmap to differentiate creations from updates
wasNew= {}

# Do a single compilation of a source file.
#
# @param executable [Executable] the executable to compile
# @param silent [Boolean] disable change propagation if true
# @param callback [Function] end callback, invoked when the compilation is done with the following parameters
# @option callback err [String] an error message. Null if no error occured
# @option callback executable [Executable] the compiled executable
compileFile = (executable, silent, callback) ->
  try 
    js = coffee.compile executable.content, {bare: true}
  catch exc
    return callback "Error while compilling executable #{executable._id}: #{exc}"
  # Eventually, write a copy with a js extension
  fs.writeFile executable.compiledPath, js, (err) =>
    return callback "Error while saving compiled executable #{executable._id}: #{err}" if err?
    logger.debug "executable #{executable._id} successfully compiled"
    # store it in local cache.
    executables[executable._id] = executable
    # clean require cache.
    requireId = path.normalize path.join process.cwd(), executable.compiledPath
    delete require.cache[requireId]
    # propagate change
    unless silent
      modelWatcher.change (if wasNew[executable._id] then 'creation' else 'update'), "Executable", executable, ['content']
      delete wasNew[executable._id]
    # and invoke final callback
    callback null, executable

# local cache of executables
executables = {}

# Executable are Javascript executable script, defined at runtime and serialized on the file-system
class Executable

  # Reset the executable local cache. It recompiles all existing executables
  #
  # @param callback [Function] invoked when the reset is done.
  # @option callback err [String] an error callback. Null if no error occured.
  @resetAll: (callback) ->
    # clean local files, and compiled scripts
    executables = {}
    utils.enforceFolderSync compiledRoot, true, logger

    fs.readdir root, (err, files) ->
      return callback "Error while listing executables: #{err}" if err?

      readFile = (file, end) -> 
        # only take coffeescript in account
        if ext isnt path.extname file
          return end()
        # creates an empty executable
        executable = new Executable {_id:file.replace ext, ''}

        fs.readFile executable.path, encoding, (err, content) ->
          return callback "Error while reading executable '#{executable._id}': #{err}" if err?
          # complete the executable content, and add it to the array.
          executable.content = content
          compileFile executable, true, (err, executable) ->
            return callback "Compilation failed: #{err}" if err?
            end()

      # each individual file must be read
      async.forEach files, readFile, (err) -> 
        logger.debug 'Local executables cached successfully reseted' unless err?
        callback err

  # Find all existing executables.
  #
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Array<Executable>] list (may be empty) of executables
  @find: (callback) ->
    # just take the local cache and transforms it into an array.
    array = []
    array.push executable for _id, executable of executables
    callback null, array

  # Find existing executable by id, from the cache.
  #
  # @param id [String] the executable id
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executable [Executable] the corresponding executable, of null if id doesn't match any executable
  @findCached: (id, callback) ->
    callback null, if id of executables then executables[id] else null

  # The unic file name of the executable, which is also its id.
  _id: null

  # The executable content (Utf-8 string encoded).
  content: ''

  # Executable's category
  category: ''

  # Absolute path to the executable source.
  path: ''

  # Absolute aath to the executable compiled script
  compiledPath: ''

  # Create a new executable, with its file name.
  # 
  # @param attributes object raw attributes, containing: 
  # @option attributes_id [String] its file name (without it's path).
  # @option attributes content [String] the file content. Empty by default.
  constructor: (attributes) ->
    @_id = attributes._id
    @content = attributes.content || ''
    @category = attributes.category ||''
    @path = path.join root, @_id+ext
    @compiledPath = path.join compiledRoot, @_id+'.js'

  # Save (or update) a executable and its content.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  save: (callback) =>
    wasNew[@_id] = !(@_id of executables)
    fs.writeFile @path, @content, encoding, (err) =>
      return callback "Error while saving executable #{@_id}: #{err}" if err?
      logger.debug "executable #{@_id} successfully saved"
      # Trigger the compilation.
      compileFile @, false, callback

  # Remove an existing executable.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  remove: (callback) =>
    fs.exists @path, (exists) =>
      return callback "Error while removing executable #{@_id}: this executable does not exists" if not exists
      delete executables[@_id]
      fs.unlink @path, (err) =>
        return callback "Error while removing executable #{@_id}: #{err}" if err?
        fs.unlink @compiledPath, (err) =>
          logger.debug "executable #{@_id} successfully removed"
          # propagate change
          modelWatcher.change 'deletion', "Executable", @
          callback null, @

module.exports = Executable