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

Rule = require '../model/Rule'
TurnRule = require '../model/TurnRule'
Executable = require '../model/Executable'
async = require 'async'
Item = require '../model/Item'
Field = require '../model/Field'
Player = require '../model/Player'
utils = require '../utils'
path = require 'path'
fs = require 'fs'
logger = require('../logger').getLogger 'service'

# Local cache of existing rules.
# Rules are stored with their name as index.
rules = {}
# frequency, in seconds.
frequency = utils.confKey 'turn.frequency'

# Compute the remaining time in milliseconds before the next turn execution
#
# @return number of milliseconds before the next turn.
nextTurn= () ->
  (frequency-new Date().getSeconds()%frequency)*1000-(new Date().getMilliseconds())

# Regular expression to extract dependencies from rules
depReg = /(.*)\s=\srequire\((.*)\);\n/

# The RuleService is somehow the rule engine: it indicates which rule are applicables at a given situation 
#
# @Todo: refresh cache when executable changes... 
class _RuleService

  # RuleService constructor.
  # Gets the existing executables, and store their rules.
  constructor: ->
    # Reset the local cache
    Executable.resetAll =>
      # Trigger first turn execution
      setTimeout @triggerTurn, nextTurn(), (->), true

        
  # Exports existing rules to clients: turn rules are ignored and execute() function is not exposed.
  #
  # @param callback [Function] callback executed when rules where exported. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] exported rules, in text, indexed by rule ids.
  export: (callback) =>
    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = {}
      readContent = (executable, done) =>
        fs.readFile executable.compiledPath, (err, content) =>
          return callback "Failed to export rules. Error while reading rule #{executable.compiledPath}: #{err}" if err?
          content = content.toString()
          if content.indexOf "})(Rule);" isnt -1
            # removes the executable part
            content = content.replace '\n    this.execute = __bind(this.execute, this);\n', '\n'

            start = content.search /\s{2}.*\.prototype\.execute\s=\sfunction\(.*\)\s\{/i
            end = content.indexOf('\n  };', start)-1

            content = content.substring(0, start)+content.substring end+6
            # gets the required dependencies
            deps = []
            vars = []
            while -1 isnt content.search depReg
              # removes the require directive and extract relevant variable and path
              content = content.replace depReg, (str, variable, dep)->
                deps.push dep.replace /^'\.\.\/main\//, "'"
                vars.push variable
                return ''
              # removes also the scope declaration
              content = content.replace " #{vars[vars.length-1]},", ''

            # replace module.exports by return
            content = content.replace 'module.exports =', 'return'
            
            # adds the define part
            content = "define('#{executable._id}', [#{deps.join ','}], function(#{vars.join ','}){\n#{content}\n});"
            
            # and keep the remaining code
            rules[executable._id] = content 
          done()

      # read content of all existing executables
      async.forEach executables, readContent, (err) =>
        callback err, rules
        
  # Resolves the applicable rules for a given situation.
  #
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  #
  # @overload resolve(playerId, callback)
  #   Resolves applicable rules at for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(actorId, x, y, callback)
  #   Resolves applicable rules at a specified coordinate
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actorId, targetId, callback)
  #   Resolves applicable rules at for a specific target
  #   @param targetId [ObjectId] the targeted item's id
  resolve: (args..., callback) =>
    if args.length is 1
      # only playerId specified. Retrieve corresponding account
      playerId = args[0]
      Player.findOne {_id: playerId}, (err, player) =>
        return callback "Cannot resolve rules. Failed to retrieve player (#{playerId}): #{err}" if err?
        return callback "No player with id #{playerId}" unless player?
        # at last, resolve rules.
        logger.debug "resolve rules for player #{playerId}"
        @_resolve player, [player], callback
    else if args.length is 2
      # actorId and targetId are specified. Retrieve corresponding items
      actorId = args[0]
      targetId = args[1]
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result._id.equals actorId
        target = result for result in results when result._id.equals targetId
        return callback "No actor with id #{actorId}" unless actor?
        return callback "No target with id #{targetId}" unless target?
        # at last, resolve rules.
        logger.debug "resolve rules for actor #{actorId} and #{targetId}"
        @_resolve actor, [target], callback
    else if args.length is 3 
      actorId = args[0]
      x = args[1]
      y = args[2]
      # targets must be resolved with a query.
      Item.find {$or:[{_id: actorId},{x: x, y:y}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or items at position x:#{x} y:#{y}: #{err}" if err?
        actor = null
        for result,i in results 
          if result._id.equals actorId
            actor = result
            results.splice i, 1
            break
        return callback "No actor with id #{actorId}" unless actor?
        return callback "Cannot resolve rules for actor #{actorId} on map if it does not have a map !" unless actor.map?
        # Gets also field at the coordinate
        Field.findOne {map: actor.map._id, x:x, y:y}, (err, field) =>
          return callback "Cannot resolve rules. Failed to retrieve field at position x:#{x} y:#{y}: #{err}" if err?
          results.splice 0, 0, field if field?
          logger.debug "resolve rules for actor #{actorId} at x:#{x} y:#{y}"
          @_resolve actor, results, callback
    else 
      throw new Error "resolve() must be call with player id or actor and target ids, or actor id and coordinates"

  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleName [String] the executed rule name
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  #
  # @overload execute(ruleName, playerId, callback)
  #   Executes a specific rule for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(ruleName, actorId, targetId, callback)
  #   Executes a specific rule for an actor and a given target
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param targetId [ObjetId] the targeted item
  execute: (ruleName, args..., callback) =>
    actor = null
    target = null
    # second part of the process
    process = =>
      logger.debug "execute rule #{ruleName} of #{actor._id} for #{target._id}"
      # then resolve rules
      @_resolve actor, [target], (err, rules) =>
        # if the rule does not apply, leave right now
        return callback "Cannot resolve rule #{ruleName}: #{err}" if err?
        rule = rule for rule in rules[target._id] when rule.name is ruleName
        return callback "The rule #{ruleName} of #{actor._id} does not apply any more for #{target._id}" unless rule?
        
        # reinitialize creation and removal arrays.
        rule.created = []
        rule.removed = []
        # otherwise, execute the rule
        try 
          rule.execute actor, target, (err, result) => 
            return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?

            saved = []
            # removes objects from mongo
            logger.debug "remove model #{item._id}" for item in rule.removed
            async.forEach rule.removed, ((item, end) -> item.remove (err)-> end err), (err) => 
              return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
              # adds new objects to be saved
              saved = saved.concat rule.created
              # looks for modified linked objects
              @_filterModified actor, saved
              @_filterModified target, saved
              # saves the whole in MongoDB
              logger.debug "save modified model #{item._id}" for item in saved
              async.forEach saved, ((item, end) -> item.save (err)-> end err), (err) => 
                return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
                # everything was fine
                callback(null, result)
        catch exc
          callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{exc}"

    if args.length is 1
      playerId = args[0]
      # only playerId specified. Retrieve corresponding account
      Player.findOne {_id: playerId}, (err, player) =>
        return callback "Cannot execute rule. Failed to retrieve player (#{playerId}): #{err}" if err?
        return callback "No player with id #{playerId}" unless player?
        actor = player
        target = player
        process()

    else if args.length is 2
      actorId = args[0]
      targetId = args[1]
      # actorId and targetId are specified. Retrieve corresponding items
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return callback "Cannot execute rule. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result._id.equals actorId
        target = result for result in results when result._id.equals targetId
        return callback "No actor with id #{actorId}" unless actor?

        if target?
          process()
        else 
          # target could be also a field
          Field.findOne {_id: targetId}, (err, result) =>
            return callback "Cannot execute rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
            return callback "No target with id #{targetId}" unless result?
            target = result
            process()

    else 
      throw new Error 'execute() must be call with player id or actor and target ids'
 
  # Trigger a turn by executing turn rules
  #
  # @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
  # @option callback err [String] an error string. Null if no error occured.
  # @param _auto [Boolean] **private** used to distinguish manual and automatic turn execution
  triggerTurn: (callback, _auto = false) =>
    logger.debug 'triggers turn rules...'
    
    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = []
      # and for each of them, extract their turn rule.
      for executable in executables
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require '.\\'+ path.relative module.filename, executable.compiledPath
        rules.push obj if obj? and utils.isA obj, TurnRule

      # @todo sort rules

      # arrays of modified objects
      saved = []
      removed = []

      # function that select target of a rule and execute it on them
      selectAndExecute = (rule, end) =>
        rule.select (err, targets) =>
          # stop a first selection error.
          return callback "Failed to select targets for rule #{rule.name}: #{err}" if err?
          logger.debug "rule #{rule.name} selected #{targets.length} target(s)"

          # function that execute the current rule on a target
          execute = (target, end) =>
            rule.execute target, (err) =>
              # stop a first execution error.
              return callback "Failed to execute rule #{rule.name} on target #{target.get '_id'}: #{err}" if err?
              # store modified object for later
              saved = saved.concat rule.created
              @_filterModified target, saved
              removed = removed.concat rule.removed
              end()

          # execute on each target and leave at the end.
          async.forEach targets, execute, end

      # select and execute each turn rule
      async.forEach rules, selectAndExecute, =>
        # at the end, save and remove modified items
        removeModel = (target, end) =>
          logger.debug "remove model #{target.get '_id'}"
          target.remove (err) =>
            # stop a first execution error.
            return callback "Failed to remove model #{target.get '_id'} at the end of the turn: #{err}" if err?
            end()
        # first removals
        async.forEach removed, removeModel, => 
          saveModel = (target, end) =>
            logger.debug "save model #{target.get '_id'}"
            target.save (err) =>
              # stop a first execution error.
              return callback "Failed to save model #{target.get '_id'} at the end of the turn: #{err}" if err?
              end()
          # then saves
          async.forEach saved, saveModel, => 
            logger.debug 'end of turn'
            # trigger the next turn
            setTimeout @triggerTurn, nextTurn(), callback, true if _auto
            # return callback
            callback null


  # **private**
  # Populate the `modified` parameter array with models that have been modified.
  # For items, recursively check linked items.
  # Can also handle Fields and Players
  #
  # @param item [Object] root model that begins the analysis
  # @return an array (may be empty) of modified models
  _filterModified: (item, modified) =>
    # do not process if already known
    return if item in modified 
    # will be save if at least one path is modified
    modified.push(item) if item?.modified
    # do not go further if not an item
    return unless item instanceof Item
    properties = item.type.get('properties')
    for prop, def of properties
      if def.type is 'object'
        value = item.get prop
        # recurse if needed on linked object that are resolved
        @_filterModified(value, modified) if value? and (typeof value) isnt 'string'
      else if def.type is 'array'
        values = item.get prop
        if values
          for value, i in values
            # recurse if needed on linked object that are resolved
            @_filterModified(value, modified) if value? and (typeof value) isnt 'string'


  # **private**
  # Effectively resolve the applicable rules of the given actor at the specified coordinate.
  #
  # @param actor [Object] the concerned actor or Player
  # @param targets [Array<Item>] array of targets the targeted item
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  _resolve: (actor, targets, callback) =>
    results = {} 
    remainingTargets = 0
    
    # function called at the end of a target resolution.
    # if no target remains, the final callback is invoked.
    resolutionEnd = ->
      remainingTargets--
      callback null, results unless remainingTargets > 0

    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) ->
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = []
      # and for each of them, extract their rule.
      for executable in executables
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require '.\\'+ path.relative module.filename, executable.compiledPath
        rules.push obj if obj? and utils.isA obj, Rule

      logger.debug "#{rules.length} candidate rules"
      # evaluates the number of target. No targets ? leave immediately.
      remainingTargets = targets.length
      return callback null, results unless remainingTargets > 0

      # second part of the resolution, after the actor was resolved
      process = (err) =>
        return callback "Cannot resolve rule because actor's (#{actor._id}) linked item cannot be resolve: #{err}" if err?
 
        # process all targets in parallel.
        for target in targets
          # third part of the resolution, after target have been resolved
          process2 = (err) =>
            return callback "Cannot resolve rule because target's (#{target._id}) linked item cannot be resolve: #{err}" if err?
            results[target._id] = []

            # function applied to filter rules that apply to the current target.
            filterRule = (rule, end) ->
              try
                rule.canExecute actor, target, (err, isApplicable) ->
                  # exit at the first resolution error
                  return callback "Failed to resolve rule #{rule.name}: #{err}" if err?
                  if isApplicable
                    logger.debug "rule #{rule.name} applies"
                    results[target._id].push(rule) 
                  end() 
              catch err
                # exit at the first resolution error
                return callback "Failed to resolve rule #{rule.name}. Received exception #{err}"
            
            # resolve all rules for this target.
            async.forEach rules, filterRule, resolutionEnd
                    
          # resolve items, but not fields
          if target instanceof Item
            target.resolve process2
          else 
            process2 null

      # resolve actor, but not player
      if actor instanceof Item
        actor.resolve process
      else 
        process null


class RuleService
  _instance = undefined
  @get: ->
    _instance ?= new _RuleService()

module.exports = RuleService