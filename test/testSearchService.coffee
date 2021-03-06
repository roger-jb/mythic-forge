###
  Copyright 2010~2014 Damien Feugas

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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

utils = require '../hyperion/src/util/common'
ItemType = require '../hyperion/src/model/ItemType'
FieldType = require '../hyperion/src/model/FieldType'
EventType = require '../hyperion/src/model/EventType'
Item = require '../hyperion/src/model/Item'
Event = require '../hyperion/src/model/Event'
Player = require '../hyperion/src/model/Player'
Map = require '../hyperion/src/model/Map'
FSItem = require '../hyperion/src/model/FSItem'
Executable = require '../hyperion/src/model/Executable'
authoringService = require('../hyperion/src/service/AuthoringService').get()
service = require('../hyperion/src/service/SearchService').get()
{expect, Assertion} = require 'chai'
{flag, inspect} = require 'chai/lib/chai/utils'

Assertion.addMethod 'containsModel', (model, msg) ->
  flag @, 'message', msg if msg?
  array = flag @, 'object'
  tmp = array.filter (obj) -> model.equals obj
  this.assert tmp.length is 1, "expected \#{this} to include #{inspect model}", "expected \#{this} not to include #{inspect model}"
  this.assert utils.isA(tmp[0], model.constructor), "expected \#{this} to include #{model.constructor.name}", "expected \#{this} not to include #{model.constructor.name}"

describe 'SearchService tests', ->

  describe 'given som players, items and events', ->
    character = null
    sword = null
    talk = null
    world = null
    underworld = null
    john = null
    jack = null
    dupond = null
    talk1 = null
    talk2 = null
    talk3 = null
    ivanhoe = null
    roland = null
    arthur = null
    gladius = null
    durandal = null
    excalibur = null
    broken = null

    before (done) ->
      Player.remove {}, -> Map.remove {}, -> EventType.remove {}, -> ItemType.remove {}, -> Item.remove {}, -> Event.remove {}, -> Player.remove {}, -> Map.loadIdCache ->
        # creates some fixtures types
        character = new ItemType id: 'character', desc: 'people a player can embody', quantifiable: false, properties:
          name: {type:'string', def:null}
          stock: {type:'array', def:'Item'}
          dead: {type:'boolean', def:false}
          strength: {type:'integer', def:10}
          knight: {type:'boolean', def:false}
        character.save (err, saved) ->
          return done err if err?
          character = saved
          sword = new ItemType id: 'sword', desc: 'a simple bastard sword', quantifiable: true, properties:
            color: {type:'string', def:'grey'}
            strength: {type:'integer', def:10}
          sword.save (err, saved) ->
            return done err if err?
            sword = saved
            talk = new EventType id: 'talk', desc: 'a speech between players', properties:
              content: {type:'string', def:'---'}
              to: {type:'object', def: 'Item'}
            talk.save (err, saved) ->
              return done err if err?
              talk = saved
              world = new Map id: 'world_map', kind: 'square'
              world.save (err, saved) ->
                return done err if err?
                world = saved
                underworld = new Map id: 'underworld', kind: 'diamond'
                underworld.save (err, saved) ->
                  return done err if err?
                  underworld = saved
                  # and now some instances fixtures
                  new Item(type: sword, color:'silver', strength: 10, quantity: 1).save (err, saved) ->
                    return done err if err?
                    gladius = saved
                    new Item(type: sword, color:'silver', strength: 15, quantity: 1).save (err, saved) ->
                      return done err if err?
                      durandal = saved
                      new Item(type: sword, color:'gold', strength: 20, quantity: 1).save (err, saved) ->
                        return done err if err?
                        excalibur = saved
                        new Item(type: sword, color:'black', strength: 5, quantity: 3).save (err, saved) ->
                          return done err if err?
                          broken = saved

                          new Item(type: character, name:'Ivanhoe', strength: 20, stock:[gladius, broken], map: world, knight:true).save (err, saved) ->
                            return done err if err?
                            ivanhoe = saved
                            new Item(type: character, name:'Roland', strength: 15, dead: true, stock:[durandal], map: underworld, knight:true).save (err, saved) ->
                              return done err if err?
                              roland = saved
                              new Item(type: character, name:'Arthur', strength: 10, stock:[excalibur], map: world, knight:false).save (err, saved) ->
                                return done err if err?
                                arthur = saved

                                new Event(type:talk, content:'hi there !!', from: ivanhoe).save (err, saved) ->
                                  return done err if err?
                                  talk1 = saved
                                  new Event(type:talk, content:'hi !', from: ivanhoe, to:roland).save (err, saved) ->
                                    return done err if err?
                                    talk2 = saved
                                    new Event(type:talk, content:"Hi. I'm Rolland", from: roland, to: ivanhoe).save (err, saved) ->
                                      return done err if err?
                                      talk3 = saved

                                      new Player(email: 'Jack', provider: null, password: 'test', firstName:'Jack', lastName:'Bauer', characters:[ivanhoe]).save (err, saved) ->
                                        return done err if err?
                                        jack = saved
                                        new Player(email: 'john.doe@gmail.com', provider: 'Gmail', firstName:'John', lastName:'Doe', characters:[roland], prefs:{rank:1}).save (err, saved) ->
                                          return done err if err?
                                          john = saved
                                          new Player(email: 'DupondEtDupont@twitter.com', provider: 'Twitter', prefs:{rank:10}).save (err, saved) ->
                                            return done err if err?
                                            dupond = saved

                                            done();

    # Restore admin player for further tests
    after (done) ->
      new Player(email:'admin', password: 'admin', isAdmin:true).save done

    it 'should search by map existence', (done) ->
      service.searchInstances {map:'!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 3
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'roland not returned').to.containsModel roland
        done()

    it 'should search by map id', (done) ->
      service.searchInstances {map:"#{world.id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        expect(results, 'arthur not returned').to.containsModel arthur
        done()

    it 'should search by map kind', (done) ->
      service.searchInstances {'map.kind':"square"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        expect(results, 'arthur not returned').to.containsModel arthur
        done()

    it 'should search by map regexp', (done) ->
      service.searchInstances {'map.id':/under/i}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'roland not returned').to.containsModel roland
        done()

    it 'should search by type id', (done) ->
      service.searchInstances {type:"#{talk.id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 3
        expect(results, 'talk1 not returned').to.containsModel talk1
        expect(results, 'talk2 not returned').to.containsModel talk2
        expect(results, 'talk3 not returned').to.containsModel talk3
        done()

    it 'should search by type property', (done) ->
      service.searchInstances {'type.color': '!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 4
        expect(results, 'durandal not returned').to.containsModel durandal
        expect(results, 'gladius not returned').to.containsModel gladius
        expect(results, 'broken not returned').to.containsModel broken
        expect(results, 'excalibur not returned').to.containsModel excalibur
        done()

    it 'should search by type regexp', (done) ->
      service.searchInstances {'type.id':/char|swo/i}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 7
        expect(results, 'durandal not returned').to.containsModel durandal
        expect(results, 'gladius not returned').to.containsModel gladius
        expect(results, 'broken not returned').to.containsModel broken
        expect(results, 'excalibur not returned').to.containsModel excalibur
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'roland not returned').to.containsModel roland
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        done()

    it 'should search by multiple terms and type criteria', (done) ->
      service.searchInstances {and:[{'type.id':/r/i}, {strength:10}]}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'gladius not returned').to.containsModel gladius
        done()

    it 'should search by criteria on linked array', (done) ->
      service.searchInstances {'stock.color': 'silver'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        expect(results, 'roland not returned').to.containsModel roland
        done()

    it 'should search by linked array id', (done) ->
      service.searchInstances {'stock': excalibur.id.toString()}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'arthur not returned').to.containsModel arthur
        done()

    it 'should search by criteria on linked object', (done) ->
      service.searchInstances {'to.strength': 15}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'talk2 not returned').to.containsModel talk2
        done()

    it 'should search by linked object id', (done) ->
      service.searchInstances {'to': ivanhoe.id.toString()}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'talk3 not returned').to.containsModel talk3
        done()

    it 'should search by boolean property', (done) ->
      service.searchInstances {'dead': false}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'ivanhoe not returned').to.containsModel ivanhoe
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'roland returned').not.to.containsModel roland
        done()

    it 'should search event by from id', (done) ->
      service.searchInstances {'from': ivanhoe.id.toString()}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'talk1 not returned').to.containsModel talk1
        expect(results, 'talk2 not returned').to.containsModel talk2
        done()

    it 'should search event by from property', (done) ->
      service.searchInstances {'from.name': 'Roland'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'talk3 not returned').to.containsModel talk3
        done()

    it 'should search items by id', (done) ->
      service.searchInstances {id:"#{durandal.id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'durandal not returned').to.containsModel durandal
        done()

    it 'should search events by id', (done) ->
      service.searchInstances {id:"#{talk2.id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'talk2 not returned').to.containsModel talk2
        done()

    it 'should search by arbitrary property existence', (done) ->
      service.searchInstances {to:'!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'talk2 not returned').to.containsModel talk2
        expect(results, 'talk3 not returned').to.containsModel talk3
        done()

    it 'should search by arbitrary property number value', (done) ->
      service.searchInstances {strength: 10}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'gladius not returned').to.containsModel gladius
        done()

    it 'should search by quantity number value', (done) ->
      service.searchInstances {quantity: 3}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'broken not returned').to.containsModel broken
        done()

    it 'should search players by id', (done) ->
      service.searchInstances {id:"#{dupond.id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'dupond not returned').to.containsModel dupond
        done()

    it 'should search players by exact email', (done) ->
      service.searchInstances {email:"#{john.email}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'john not returned').to.containsModel john
        done()

    it 'should search players by regexp email', (done) ->
      service.searchInstances {email:/j/i}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'jack not returned').to.containsModel jack
        expect(results, 'john not returned').to.containsModel john
        done()

    it 'should search players by provider', (done) ->
      service.searchInstances {provider:'!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'john not returned').to.containsModel john
        expect(results, 'dupond not returned').to.containsModel dupond
        done()

    it 'should search players by preferences', (done) ->
      service.searchInstances {'prefs.rank':1}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'john not returned').to.containsModel john
        done()

    it 'should search players by character existence', (done) ->
      service.searchInstances {characters: '!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'john not returned').to.containsModel john
        expect(results, 'jack not returned').to.containsModel jack
        done()

    it 'should search players by character id', (done) ->
      service.searchInstances {characters: roland.id.toString()}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'john not returned').to.containsModel john
        done()

    it 'should search players by character property value', (done) ->
      service.searchInstances {'characters.strength': 20}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'jack not returned').to.containsModel jack
        done()

    it 'should string query be usable', (done) ->
      service.searchInstances '{"and":[{"type.id":"/r/i"}, {"strength":10}]}', (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'gladius not returned').to.containsModel gladius
        done()

    it 'should search with boolean operator between condition', (done) ->
      service.searchInstances {or:[{and:[{'type.id':/r/i}, {strength: 10}]}, {'prefs.rank': 1}, {to:'!'}]}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 5
        expect(results, 'gladius not returned').to.containsModel gladius
        expect(results, 'arthur not returned').to.containsModel arthur
        expect(results, 'john not returned').to.containsModel john
        expect(results, 'talk2 not returned').to.containsModel talk2
        expect(results, 'talk3 not returned').to.containsModel talk3
        done()

    it 'should failed on invalid string query', (done) ->
      service.searchInstances '{"and":[{"type.id":"/r/i"}, {"strength":10}]', (err) ->
        expect(err).to.include 'Unexpected end of input'
        done()

    it 'should failed on invalid json query', (done) ->
      service.searchInstances {and:{"type.id":/r/i}}, (err) ->
        expect(err).to.include 'and needs an array'
        done()

  describe 'given some types, executables and maps', ->
    itemTypes = []
    eventTypes = []
    fieldTypes = []
    maps = []
    rules = []
    turnRules = []

    before (done) ->
      # Empties the compilation and source folders content
      utils.empty utils.confKey('game.executable.source'), (err) ->
        Executable.resetAll true, (err) ->
          return done err if err?
          Map.remove {}, ->
            FieldType.remove {}, ->
              EventType.remove {}, ->
                ItemType.remove {}, -> ItemType.loadIdCache ->
                  # creates some fixtures for each searchable objects
                  created = [
                    clazz: ItemType
                    args:
                      id: 'character'
                      quantifiable: false
                      properties:
                        name: {type:'string', def:null}
                        height: {type:'float', def:1.80}
                        strength: {type:'integer', def:10}
                        knight: {type:'boolean', def:false}
                    store: itemTypes
                  ,
                    clazz: ItemType
                    args:
                      id: 'sword'
                      quantifiable: true
                      properties:
                        color: {type:'string', def:'grey'}
                        strength: {type:'integer', def:10}
                    store: itemTypes
                  ,
                    clazz: EventType
                    args:
                      id: 'penalty'
                      properties:
                        turn: {type:'integer', def:1}
                        strength: {type:'integer', def:5}
                    store: eventTypes
                  ,
                    clazz: EventType
                    args:
                      id: 'talk'
                      properties:
                        content: {type:'string', def:'---'}
                    store: eventTypes
                  ,
                    clazz: FieldType
                    args:
                      id: 'plain'
                    store: fieldTypes
                  ,
                    clazz: FieldType
                    args:
                      id: 'mountain'
                    store: fieldTypes
                  ,
                    clazz: Executable
                    args:
                      id: 'move'
                      content:"""Rule = require 'hyperion/model/Rule'
                        module.exports = new (class Move extends Rule
                          constructor: ->
                            @category= 'map'
                          canExecute: (actor, target, context, callback) =>
                            callback null, []
                          execute: (actor, target, params, context, callback) =>
                            callback null
                        )()"""
                    store: rules
                  ,
                    clazz: Executable
                    args:
                      id: 'attack'
                      content:"""Rule = require 'hyperion/model/Rule'
                        module.exports = new (class Attack extends Rule
                          constructor: ->
                            @active= false
                          canExecute: (actor, target, context, callback) =>
                            callback null, []
                          execute: (actor, target, params, context, callback) =>
                            callback null
                        )()"""
                    store: rules
                  ,
                    clazz: Executable
                    args:
                      id: 'sell'
                      content:"""TurnRule = require 'hyperion/model/TurnRule'
                        module.exports = new (class Sell extends TurnRule
                          constructor: ->
                            @rank= 3
                            @active= false
                          select: (callback) =>
                            callback null, []
                          execute: (target, callback) =>
                            callback null
                        )()"""
                    store: turnRules
                  ,
                    clazz: Executable
                    args:
                      id: 'monsters'
                      content:"""TurnRule = require 'hyperion/model/TurnRule'
                        module.exports = new (class Monsters extends TurnRule
                          constructor: ->
                            @rank= 10
                          select: (callback) =>
                            callback null, []
                          execute: (target, callback) =>
                            callback null
                        )()"""
                    store: turnRules
                  ,
                    clazz: Map
                    args:
                      name: 'world_map'
                      kind:'square'
                    store: maps
                  ,
                    clazz: Map
                    args:
                      name: 'underworld'
                      kind:'diamond'
                    store: maps
                  ]
                  create = (def) ->
                    return done() unless def?
                    obj = new def.clazz def.args
                    obj.save (err, saved) ->
                      return done err if err?
                      def.store.push saved
                      create created.splice(0, 1)[0]

                  create created.splice(0, 1)[0]

    it 'should search item types by id', (done) ->
      service.searchTypes {id:"#{itemTypes[0].id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        done()

    it 'should search field types by id', (done) ->
      service.searchTypes {id:"#{fieldTypes[1].id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'second field type not returned').to.containsModel fieldTypes[1]
        done()

    it 'should search event types by id', (done) ->
      service.searchTypes {id:"#{eventTypes[0].id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        done()

    it 'should search maps by id', (done) ->
      service.searchTypes {id:"#{maps[1].id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first map not returned').to.containsModel maps[1]
        done()

    it 'should search executable by id', (done) ->
      service.searchTypes {id:"#{rules[0].id}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should search by regexp id', (done) ->
      service.searchTypes {id:/t/i}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 6
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        expect(results, 'second event type not returned').to.containsModel eventTypes[1]
        expect(results, 'second field type not returned').to.containsModel fieldTypes[1]
        expect(results, 'second rule not returned').to.containsModel rules[1]
        expect(results, 'second turn-rule not returned').to.containsModel turnRules[1]
        done()

    it 'should search by exact content', (done) ->
      service.searchTypes {content:"#{rules[0].content}"}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should search by regexp content', (done) ->
      service.searchTypes {content:/extends rule/i}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'first rule not returned').to.containsModel rules[0]
        expect(results, 'second rule not returned').to.containsModel rules[1]
        done()

    it 'should search by property existence', (done) ->
      service.searchTypes {strength: '!'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 3
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        expect(results, 'second item type not returned').to.containsModel itemTypes[1]
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        done()

    it 'should search by property number value', (done) ->
      service.searchTypes {strength: 10}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        expect(results, 'second item type not returned').to.containsModel itemTypes[1]
        done()

    it 'should search by property string value', (done) ->
      service.searchTypes {content: '---'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'second event type not returned').to.containsModel eventTypes[1]
        done()

    it 'should search by property boolean value', (done) ->
      service.searchTypes {knight: false}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        done()

    it 'should search by property regexp value', (done) ->
      service.searchTypes {content: /.*/}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 5
        expect(results, 'second event type not returned').to.containsModel eventTypes[1]
        expect(results, 'first rule not returned').to.containsModel rules[0]
        expect(results, 'second rule not returned').to.containsModel rules[1]
        expect(results, 'first turn-rule not returned').to.containsModel turnRules[0]
        expect(results, 'second turn-rule not returned').to.containsModel turnRules[1]
        done()

    it 'should search by quantifiable', (done) ->
      service.searchTypes {quantifiable: true}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'second item type not returned').to.containsModel itemTypes[1]
        done()

    it 'should combined search with triple or', (done) ->
      service.searchTypes {or: [{id: 'character'}, {id: 'move'}, {strength:'!'}]}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 4
        expect(results, 'first item type not returned').to.containsModel itemTypes[0]
        expect(results, 'second item type not returned').to.containsModel itemTypes[1]
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should combined search with triple and', (done) ->
      service.searchTypes {and: [{id: 'move'}, {content: /extends rule/i}, {category:'map'}]}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should combined search with and or', (done) ->
      service.searchTypes {or: [{and: [{id: 'attack'}, {content: /extends rule/i}]}, {strength:5}]}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        expect(results, 'second rule not returned').to.containsModel rules[1]
        done()

    it 'should search by rank value', (done) ->
      service.searchTypes {rank: 3}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first turn-rule not returned').to.containsModel turnRules[0]
        done()

    it 'should search by active value', (done) ->
      service.searchTypes {active: false}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'second rule not returned').to.containsModel rules[1]
        expect(results, 'first turn-rule not returned').to.containsModel turnRules[0]
        done()

    it 'should search by exact category', (done) ->
      service.searchTypes {category: 'map'}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should search by category regexp', (done) ->
      service.searchTypes {category: /m.*/}, (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results, 'first rule not returned').to.containsModel rules[0]
        done()

    it 'should string query be usable', (done) ->
      service.searchTypes '{"or": [{"and": [{"id": "attack"}, {"content": "/extends rule/i"}]}, {"strength":5}]}', (err, results)->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results, 'first event type not returned').to.containsModel eventTypes[0]
        expect(results, 'second rule not returned').to.containsModel rules[1]
        done()

  describe 'given some FSItem', ->
    files = []

    before (done) ->
      # Empties the source folder
      utils.empty utils.confKey('game.client.dev'), (err) ->
        return done err if err?
        authoringService.init (err) ->
          return done err if err?
          created = [
            new FSItem(
              path: 'index.html'
              content: new Buffer '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta version="{{version}}">
    <link href="style/common.css" rel="stylesheet">
    <script src="script/vendor/modernizr-2.7.1-min.js"></script>
  </head>
  <body>
    <div id="view" data-ng-view class="ng-class:routeName">
      <progress></progress>
    </div>
    <script src="conf.js"></script>
    <script data-main='script/main' src="script/vendor/require-2.1.11-min.js"></script>
  </body>
</html>
              ''')
            new FSItem(
              path: 'script/app.coffee'
              content: new Buffer '''
define [
  'angular',
  'util/common'
  'controller/login'
  'angular-route'
], (angular, utils, LoginCtrl) ->

  app = angular.module 'app', ['ngRoute']

  app.config ['$locationProvider', '$routeProvider', (location, route) ->

    # use push state
    location.html5Mode true
    # configure routing
    route.when "#{conf.basePath}login",
      name: 'login'
      templateUrl: "#{conf.rootPath}template/login.html"
      controller: LoginCtrl
      controllerAs: 'ctrl'
      resolve: LoginCtrl.checkRedirect
    route.otherwise
      redirectTo: "#{conf.basePath}login"
  ]
  app
              ''')
            new FSItem(
              path: 'script/controller/login.coffee'
              content: new Buffer '''
define ['jquery', 'util/common'], ($, {parseError}) ->

  class Login

    @$inject: ['check', '$location', '$filter']

    error: null

    location: null

    constructor: (err, @location, filter) ->
      document.title = filter('i18n') 'titles.login'
      @error = parseError err if err?
              ''')
          ]
          create = (item) ->
            return done() unless item?
            authoringService.save item, (err, saved) ->
              return done err if err?
              files.push saved unless item.isFolder
              create created.splice(0, 1)[0]
          create created.splice(0, 1)[0]

    it 'should string search within files', (done) ->
      service.searchFiles 'conf', (err, results) ->
        return done err if err?
        expect(results).to.have.lengthOf 2
        expect(results).to.containsModel files[0]
        expect(results).to.containsModel files[1]
        done()

    it 'should regexp search within files', (done) ->
      service.searchFiles '/App/i', (err, results) ->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results).to.containsModel files[1]
        done()

    it 'should string search within files with filters', (done) ->
      service.searchFiles 'conf', '\.html$', (err, results) ->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results).to.containsModel files[0]
        done()

    it 'should regexp search within files with filters', (done) ->
      service.searchFiles '/define/', 'controller', (err, results) ->
        return done err if err?
        expect(results).to.have.lengthOf 1
        expect(results).to.containsModel files[2]
        done()