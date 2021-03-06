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
'use strict'

define [
  'model/BaseModel'
  'model/Field'
  'model/Item'
  'utils/utilities'
], (Base, Field, Item, utils) ->

  # Client cache of maps.
  class _Maps extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Map'

  # Modelisation of a single Map.
  # Not wired to the server : use collections Maps instead
  class Map extends Base.Model

    # Local cache for models.
    @collection: new _Maps @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Map'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['kind', 'tileDim']

    # **private**
    # flag to avoid multiple concurrent server call.
    _consultRunning: false

    # Map constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes

      utils.onRouterReady =>
        # connect server response callbacks
        app.sockets.game.on 'consultMap-resp', @_onConsult

    # Allows to retrieve items and fields on this map by coordinates, in a given rectangle.
    #
    # @param low [Object] lower-left coordinates of the rectangle
    # @option args low x [Number] abscissa lower bound (included)
    # @option args low y [Number] ordinate lower bound (included)
    # @param up [Object] upper-right coordinates of the rectangle
    # @option args up x [Number] abscissa upper bound (included)
    # @option args up y [Number] ordinate upper bound (included)  
    consult: (low, up) =>
      return if @_consultRunning
      @_consultRunning = true
      console.log "Consult map #{@id} between #{low.x}:#{low.y} and #{up.x}:#{up.y}"
      # emit the message on the socket.
      app.sockets.game.emit 'consultMap', utils.rid(), @id, low.x, low.y, up.x, up.y

    # **private**
    # Return callback of consultMap server operation.
    #
    # @param reqId [String] client request id
    # @param err [String] error string. null if no error occured
    # @param items [Array<Item>] array (may be empty) of concerned items.
    # @param fields [Array<Field>] array (may be empty) of concerned fields.
    _onConsult: (reqId, err, items, fields) =>
      if @_consultRunning
        @_consultRunning = false
        return console.error "Fail to retrieve map content: #{err}" if err?
        # add them to the collection (Item model will be created)
        console.log "#{items.length} map item(s) received #{@id}"
        Item.collection.add items
        console.log "#{fields.length} map field(s) received on #{@id}"
        Field.collection.add fields
