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
'use strict'

define [
  'jquery'
  'underscore'
  'ace/ace'
  'i18n!nls/widget'
  'widget/base'
],  ($, _, ace, i18n, Base) ->

  prompt = "<div class='prompt'>"+
    "<div class='find'>"+
      "<span>#{i18n.advEditor.find}</span>"+
        "<input type='text'/>"+
        "<a class='previous icon' href='#' title='#{i18n.advEditor.findPrev}'><i class='ui-icon ui-icon-carat-1-n'></i></a>"+
        "<a class='next icon' href='#' title='#{i18n.advEditor.findNext}'><i class='ui-icon ui-icon-carat-1-s'></i></a>"+
        "<a class='close icon' href='#'><i class='ui-icon ui-icon-close'></i></a>"+
      "</div>"+
      "<div class='replace'>"+
        "<span>#{i18n.advEditor.replaceBy}</span>"+
        "<input type='text'/>"+
        "<a class='first icon' href='#' title='#{i18n.advEditor.replace}'><i class='ui-icon ui-icon-transfer-e-w'></i></a>"+
        "<a class='all icon' href='#' title='#{i18n.advEditor.replaceAll}'><i class='ui-icon ui-icon-transferthick-e-w'></i></a>"+
      "</div>"+
    "</div>"

  # set path to avoid problems after optimization
  path = requirejs.s.contexts._.config.baseUrl+requirejs.s.contexts._.config.paths.ace
  ace.config.set 'modePath', path
  ace.config.set 'themePath', path
  ace.config.set 'workerPath', path

  # Widget that encapsulate the Ace editor to expose a more jQuery-ui compliant interface
  # Triggers a `change`event when necessary.
  class AdvEditor extends Base

    # **private**
    # the ace editor
    _editor: null

    # **private**
    # prompt to get find commands
    _prompt: null

    # **private**
    # number of occurences previously found
    _foundNum: 0

    # **private**
    # Builds rendering
    constructor: (element, options) ->
      super element, options
      
      @$el.addClass 'adv-editor'

      # creates and wire the editor
      node = $('<div></div>').appendTo @$el
      @_editor = ace.edit node[0]
      session = @_editor.getSession()
      
      session.on 'change', => 
        # update inner value and fire change event
        @options.text = @_editor.getValue()
        @$el.trigger 'change', @options.text
      
      # configure it
      session.setUseSoftTabs true

      @_editor.setScrollSpeed 5

      # special implementation of find command
      @_editor.commands.addCommand
        name: 'find'
        bindKey: win:'Ctrl-F', mac:'Command-F'
        exec: => @_onShowPrompt false

      # special implementation of replace command
      @_editor.commands.addCommand
        name: 'replace'
        bindKey: win:'Ctrl-H', mac:'Command-Option-F'
        exec: => @_onShowPrompt true

      # fills its content
      @setOption 'text', @options.text
      @setOption 'tabSize', @options.tabSize
      @setOption 'theme', @options.theme
      @setOption 'mode', @options.mode
            
      # creates prompt
      @_prompt = $(prompt).appendTo @$el

      # progressive find while entering input
      @_prompt.on 'keyup', '.find input', _.throttle (=> @_onFind()), 100
      # bind prompt commands
      @_prompt.on 'click', '.close', (event) => @_onClosePrompt event
      # search next and previous
      @_prompt.on 'click', '.previous', (event) => @_onFind event, false
      @_prompt.on 'click', '.next', (event) => @_onFind event, true
      # replace first and all occurences
      @_prompt.on 'click', '.first', (event) => @_onReplace event
      @_prompt.on 'click', '.all', (event) => @_onReplace event, true

    # Frees DOM listeners
    dispose: =>
      @_editor.destroy()
      super()

    # This method might be called when the editor is shown, to resize it properly
    resize: =>
      _.defer => @_editor.resize true        

    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      console.log "set option #{key}"
      return unless key in ['text', 'mode', 'theme', 'tabSize']
      switch key
        when 'text' 
          # keeps the undo manager
          undoMgr = @_editor.getSession().getUndoManager()
          # keeps the cursor position if possible
          position = @_editor.selection.getCursor()
          @_editor.setValue value
          # setValue will select all new text. Reset the cursor to original position.
          @_editor.clearSelection()
          @_editor.selection.moveCursorToPosition position
          @_editor.getSession().setUndoManager undoMgr
        when 'tabSize'
          @options.tabSize = value
          @_editor.getSession().setTabSize value
        when 'theme'
          @options.theme = value
          @_editor.setTheme "ace/theme/#{value}"
        when 'mode'
          @options.mode = value
          @_editor.getSession().setMode "ace/mode/#{value}"
   
    # **private**
    # Show the find/replace prompt with an animation (Css)
    #
    # @param withReplace [Boolean] display the replace prompt
    _onShowPrompt: (withReplace) =>
      # change the searched content
      selection = @_editor.session.getTextRange @_editor.getSelectionRange()
      @_prompt.find('.find input').val if selection then selection else ''
      # show prompt with replace and focus input
      @_prompt.toggleClass('and-replace', withReplace).addClass 'shown'
      @_prompt.find('.find input').focus()

    # **private**
    # Close the find/replace prompt
    #
    # @param event [Event] cancelled click event
    _onClosePrompt: (event) => 
      event?.preventDefault()
      # hide prompt and focus editor
      @_prompt.removeClass 'shown'
      @_editor.focus()

    # **private**
    # Find all, next or previous occurences of the searched text
    #
    # @param event [Event] cancelled click event
    # @param next [Boolean] true to find next, false to find previous, other to find all
    _onFind: (event, next) =>
      event?.preventDefault()
      if next is true
        @_editor.findNext {}, true
      else if next is false
        @_editor.findPrevious {}, true
      else
        # search first
        @_foundNum = @_editor.find @_prompt.find('.find input').val(), {}, true

    # **private**
    # Replace first or all occurences of the searched text with replace text
    #
    # @param event [Event] cancelled click event
    # @param all [Boolean] true to replace all occurences
    _onReplace: (event, all) =>
      event?.preventDefault()
      value = @_prompt.find('.replace input').val()
      options = needle: @_prompt.find('.find input').val()
      if all
        @_editor.replaceAll value, options
      else
        @_editor.replace value, options

  # widget declaration
  AdvEditor._declareWidget 'advEditor', 

    # the edited text
    # read-only: use `setOption('text')` to modify.
    text: ''

    # mode used to parse content, 'text' by default.
    # read-only: use `setOption('mode')` to modify.
    mode: 'text'

    # theme used to display content, 'clouds' by default.
    # read-only: use `setOption('theme')` to modify.
    theme: 'clouds'

    # number of spaces used to replace tabs, 2 by default.
    # read-only: use `setOption('tabSize')` to modify.
    tabSize: 2