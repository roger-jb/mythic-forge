###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

define
  loadableImage:
    noImage: 'Aucune image'

  search:
    noResults: 'Aucun résultat'
    oneResult: '1 résultat'
    nbResults: '%d résultats'

  spriteImage:
    dimensions: 'l x h '
    sprites: 'Sprites :'
    rank: 'Rang'
    name: 'Nom'
    number: 'Nombre'
    duration: 'Durée'
    add: 'Nouveau'
    newName: 'sprite'
    unsavedSprite: 'Le nom du sprite "%s" est déjà utilisé, merci d\'en choisir un autre'

  property:
    isNull: 'nul'
    isTrue: 'vrai'
    isFalse: 'faux'
    objectTypes: [{
      val:'Any'
      name:"n'importe quoi"
    },{
      val:'Item'
      name:'objets'
    },{
      val:'Event'
      name:'évènements'
    },{
      val:'Field'
      name:'terrains'
    }]