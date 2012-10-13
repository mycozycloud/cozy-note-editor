## TODO: fire an history event whenever a button is clicked

### ------------------------------------------------------------------------
# CLASS FOR THE COZY NOTE EDITOR
#
# usage : 
#
# newEditor = new CNEditor( iframeTarget,callBack )
#   iframeTarget = iframe where the editor will be nested
#   callBack     = launched when editor ready, the context 
#                  is set to the editorCtrl (callBack.call(this))
# properties & methods :
#   replaceContent    : (htmlContent) ->  # TODO: replace with markdown
#   _keyPressListener : (e) =>
#   _insertLineAfter  : (param) ->
#   _insertLineBefore : (param) ->
#   
#   editorIframe      : the iframe element where is nested the editor
#   editorBody$       : the jquery pointer on the body of the iframe
#   _lines            : {} an objet, each property refers a line
#   _highestId        : 
#   _firstLine        : pointes the first line : TODO : not taken into account 
###

class exports.CNEditor extends Backbone.View

    ###
    #   Constructor : newEditor = new CNEditor( iframeTarget,callBack )
    #       iframeTarget = iframe where the editor will be nested
    #       callBack     = launched when editor ready, the context 
    #                      is set to the editorCtrl (callBack.call(this))
    ###
    constructor : (elementTarget,callBack) ->
        #iframe$ = $('<iframe style="width:50%;height:100%"></iframe>').appendTo(iframeTarget)
        #iframe$ = $(iframeTarget).replaceWith('<iframe  style="width:50%;height:100%"></iframe>')
        # 
        
        if elementTarget.nodeName == "IFRAME"
            # when getSelection is called on an iframe
            @getEditorSelection = () ->
                return rangy.getIframeSelection elementTarget
            @saveEditorSelection = () ->
                return rangy.saveSelection(rangy.dom.getIframeWindow elementTarget)
            
            iframe$ = $(elementTarget)
            iframe$.on 'load', () =>

                # 1- preparation of the iframe
                editor_html$ = iframe$.contents().find("html")
                editorBody$  = editor_html$.find("body")
                editorBody$.parent().attr('id','__ed-iframe-html')
                editorBody$.attr("contenteditable", "true")
                editorBody$.attr("id","__ed-iframe-body")
                editor_head$ = editor_html$.find("head")
                editor_css$  = editor_head$.html('<link href="stylesheets/app.css" rel="stylesheet">')
            
                # 2- set the properties of the editor
                @editorBody$  = editorBody$   # label <body> of the iframe
                @editorTarget = elementTarget # <iframe>
                @_lines       = {}            # contains every line
                @newPosition  = true          # true only if cursor has moved
                @_highestId   = 0             # last inserted line identifier
                @_deepest     = 1             # current maximum indentation
                @_firstLine   = null          # pointer to the first line
                @_history     =               # for history management
                    index        : 0
                    history      : [null]
                    historySelect: [null]
                    historyScroll: [null]
                @_lastKey     = null      # last pressed key (avoid duplication)
                
                # 3- initialize event listeners
                editorBody$.prop( '__editorCtl', this)
                editorBody$.on 'mouseup', () =>
                    @newPosition = true
                editorBody$.on 'keypress', @_keyPressListener
                editorBody$.on 'keyup', () ->
                    iframe$.trigger jQuery.Event("onKeyUp")
                editorBody$.on 'paste', (e) =>
                    console.log "pasting..."
                    @paste(e)

                # 4- return a ref to the editor's controler
                callBack.call(this)
                return this

        else
            console.log "target is not an iframe..."
            # when getSelection is on a node
            @getEditorSelection = () ->
                return rangy.getSelection()
            @saveEditorSelection = () ->
                return rangy.saveSelection()
                
            node$ = $(elementTarget)
            allSetter = () =>
                # 1- preparation of the iframe
                editorBody$  = node$
                editorBody$.attr("contenteditable", "true")
                editorBody$.attr("id","__ed-iframe-body")
            
                # 2- set the properties of the editor
                @editorBody$  = editorBody$   # label <body> of the iframe
                @editorTarget = elementTarget # <iframe>
                @_lines       = {}            # contains every line
                @newPosition  = true          # true only if cursor has moved
                @_highestId   = 0             # last inserted line identifier
                @_deepest     = 1             # current maximum indentation
                @_firstLine   = null          # pointer to the first line
                @_history     =               # for history management
                    index        : 0
                    history      : [null]
                    historySelect: [null]
                    historyScroll: [null]
                @_lastKey     = null      # last pressed key (avoid duplication)
                
                # 3- initialize event listeners
                editorBody$.prop( '__editorCtl', this)
                editorBody$.on 'keypress', @_keyPressListener
                editorBody$.on 'mouseup', () =>
                    @newPosition = true
                editorBody$.on 'keyup', () ->
                    node$.trigger jQuery.Event("onKeyUp")
                editorBody$.on 'paste', (e) =>
                    console.log "pasting..."
                    @paste(e)
                # 4- return a ref to the editor's controler
                callBack.call(this)
                return this
            allSetter()


    ### ------------------------------------------------------------------------
    # Find the maximal deep (thus the deepest line) of the text
    # TODO: improve it so it only calculates the new depth from the modified
    #       lines (not all of them)
    # TODO: set a class system rather than multiple CSS files. Thus titles
    #       classes look like "Th-n depth3" for instance if max depth is 3
    # note: These todos arent our priority for now
    ###
    _updateDeepest : ->
        max = 1
        lines = @_lines
        for c of lines
            if @editorBody$.children("#" + "#{lines[c].lineID}").length > 0 and lines[c].lineType == "Th" and lines[c].lineDepthAbs > max
                max = @_lines[c].lineDepthAbs
                
        # Following code is way too ugly to be kept
        # It needs to be replaced with a way to change a variable in a styl or
        # css file... but I don't even know if it is possible.
        if max != @_deepest
            @_deepest = max
            if max < 4
                @replaceCSS("stylesheets/app-deep-#{max}.css")
            else
                @replaceCSS("stylesheets/app-deep-4.css")
        
    ### ------------------------------------------------------------------------
    # Initialize the editor content from a html string
    ###
    replaceContent : (htmlContent) ->
        @editorBody$.html( htmlContent )
        @_readHtml()
        #@_buildSummary()

    ### ------------------------------------------------------------------------
    # Clear editor content
    ###
    deleteContent : () ->
        @editorBody$.html '<div id="CNID_1" class="Tu-1"><span></span><br></div>'
        # update the controler
        @_readHtml()
        #@_buildSummary()
    
    
    ### ------------------------------------------------------------------------
    # Returns a markdown string representing the editor content
    ###
    getEditorContent : () ->
        cozyContent = @editorBody$.html()
        return @_cozy2md cozyContent
        
    ### ------------------------------------------------------------------------
    # Sets the editor content from a markdown string
    ###
    setEditorContent : (mdContent) ->
        cozyContent = @_md2cozy mdContent
        @editorBody$.html cozyContent
        # update the controler
        @_readHtml()
                  
    ###
    # Change the path of the css applied to the editor iframe
    ###
    replaceCSS : (path) ->
        $(this.editorTarget).contents().find("link[rel=stylesheet]").attr({href : path})


    ### ------------------------------------------------------------------------
    # UTILITY FUNCTIONS
    # used to set ranges and normalize selection
    # 
    # parameters: elt  :  a dom object with only textNode children
    ###
    _putEndOnEnd : (range, elt) ->
        if elt.lastChild?
            offset = elt.lastChild.textContent.length
            range.setEnd(elt.lastChild, offset)
        else
            range.setEnd(elt, 0)
            
    _putStartOnEnd : (range, elt) ->
        if elt.lastChild?
            offset = elt.lastChild.textContent.length
            range.setStart(elt.lastChild, offset)
        else
            range.setStart(elt, 0)
            
    _putEndOnStart : (range, elt) ->
        if elt.firstChild?
            range.setEnd(elt.firstChild, 0)
        else
            range.setEnd(elt, 0)
            
    _putStartOnStart : (range, elt) ->
        if elt.firstChild?
            range.setStart(elt.firstChild, 0)
        else
            range.setStart(elt, 0)
            
    _normalize : (range) ->
            
        startContainer = range.startContainer
        # 1. if startC is a div
        if startContainer.nodeName == "DIV"
            
            # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
            if range.startOffset < startContainer.childNodes.length - 1
                # place caret at the beginning of the next child
                elt = startContainer.childNodes[range.startOffset]
                @_putStartOnStart(range, elt)
            # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
            else
                # place caret at the end of the last child (before br)
                elt = startContainer.lastChild.previousElementSibling
                @_putStartOnEnd(range, elt)
                
        # 2. if startC is a span, a, img
        else if startContainer.nodeName in ["SPAN","IMG","A"]
            # 2.1 if caret is between two textNode children
            if range.startOffset < startContainer.childNodes.length
                # place caret at the beginning of the next child
                elt = startContainer.childNodes[range.startOffset]
                @_putStartOnStart(range, elt)
            # 2.1 if caret is after last textNode
            else
                # place caret at the end of the last child
                elt = startContainer.lastChild
                @putStartOnEnd(range, elt)
                
        # 3. if startC is a textNode ;   do nothing
                
        endContainer = range.endContainer
        # 1. if endC is a div
        if endContainer.nodeName == "DIV"
            # 1.1 if caret is between two children <div>|<></>|<></> <br> </div>
            if range.endOffset < endContainer.childNodes.length - 1
                # place caret at the beginning of the next child
                elt = endContainer.chilNodes[range.endOffset]
                @_putEndOnStart(range, elt)
            # 1.2 if caret is around <br>          <div> <></> <></>|<br>|</div>
            else
                # place caret at the end of the last child (before br)
                elt = endContainer.lastChild.previousElementSibling
                @_putEndOnEnd(range, elt)
                
        # 2. if endC is a span, a, img
        else if endContainer.nodeName in ["SPAN","IMG","A"]
            # 2.1 if caret is between two textNode children
            if range.endOffset < endContainer.childNodes.length
                # place caret at the beginning of the next child
                elt = endContainer.childNodes[range.endOffset]
                @_putEndOnStart(range, elt)
            # 2.1 if caret is after last textNode
            else
                # place caret at the end of the last child
                elt = endContainer.lastChild
                @putEndOnEnd(range, elt)
        # 3. if endC is a textNode ;   do nothing

        
        # We suppose that a div can be selected only when clicking on the right
        # 1. if it's a div
        #startContainer = range.startContainer
        #if startContainer.nodeName == "DIV"
            #elt = startContainer.lastChild.previousElementSibling
            #@_putStartOnEnd(range, elt)
        # 2. if it's between two labels span/img/a
        #else if ! startContainer.parentNode.nodeName in ["SPAN","IMG","A"]
            #next = startContainer.nextElementSibling
            #prev = startContainer.previousElementSibling
            #if next != null
                #@_putStartOnStart(range, next)
            #else
                #@_putEndOnEnd(range, prev)
        # same with the selection end
        # 1. if it's a div
        #endContainer = range.endContainer
        #if endContainer.nodeName == "DIV"
            #elt = endContainer.lastChild.previousElementSibling
            #@_putEndOnEnd(range, elt)
        #else if ! endContainer.parentNode in ["SPAN","IMG","A"]
            #next = endContainer.nextElementSibling
            #prev = endContainer.previousElementSibling
            #if next != null
                #@_putStartOnStart(range, next)
            #else
                #@_putEndOnEnd(range, prev)

    
    ### ------------------------------------------------------------------------
    #    The listener of keyPress event on the editor's iframe... the king !
    ###
    # 
    # Params :
    # e : the event object. Interesting attributes : 
    #   .which : added by jquery : code of the caracter (not of the key)
    #   .altKey
    #   .ctrlKey
    #   .metaKey
    #   .shiftKey
    #   .keyCode
    ###
    # SHORTCUT  |-----------------------> (suggestion: see jquery.hotkeys.js ? )
    #
    # Definition of a shortcut : 
    #   a combination alt,ctrl,shift,meta
    #   + one caracter(.which) 
    #   or 
    #     arrow (.keyCode=dghb:) or 
    #     return(keyCode:13) or 
    #     bckspace (which:8) or 
    #     tab(keyCode:9)
    #   ex : shortcut = 'CtrlShift-up', 'Ctrl-115' (ctrl+s), '-115' (s),
    #                   'Ctrl-'
    ###
    # Variables :
    #   metaKeyStrokesCode : ex : ="Alt" or "CtrlAlt" or "CtrlShift" ...
    #   keyStrokesCode     : ex : ="return" or "_102" (when the caracter 
    #                               N°102 f is stroke) or "space" ...
    #
    _keyPressListener : (e) =>
        # 1- Prepare the shortcut corresponding to pressed keys
        # TODO: when pressed key is a letter, prevent the browser default action
        #       and an unDo after a sequence of letters shoud delete it
        metaKeyStrokesCode = `(e.altKey ? "Alt" : "") + 
                              (e.ctrlKey ? "Ctrl" : "") + 
                              (e.shiftKey ? "Shift" : "")`
        switch e.keyCode
            when 13 then keyStrokesCode = "return"
            when 35 then keyStrokesCode = "end"
            when 36 then keyStrokesCode = "home"
            when 33 then keyStrokesCode = "pgUp"
            when 34 then keyStrokesCode = "pgDwn"
            when 37 then keyStrokesCode = "left"
            when 38 then keyStrokesCode = "up"
            when 39 then keyStrokesCode = "right"
            when 40 then keyStrokesCode = "down"
            when 9  then keyStrokesCode = "tab"
            when 8  then keyStrokesCode = "backspace"
            when 32 then keyStrokesCode = "space"
            when 27 then keyStrokesCode = "esc"
            when 46 then keyStrokesCode = "suppr"
            else
                switch e.which # TODO : to be deleted if it works with e.keyCode
                    when 32  then keyStrokesCode = "space"  
                    when 8   then keyStrokesCode = "backspace"
                    when 97  then keyStrokesCode = "A"
                    when 115 then keyStrokesCode = "S"
                    when 118 then keyStrokesCode = "V"
                    when 121 then keyStrokesCode = "Y"
                    when 122 then keyStrokesCode = "Z"
                    #else  keyStrokesCode = e.which
                    else keyStrokesCode = "other"
        shortcut = metaKeyStrokesCode + '-' + keyStrokesCode
        
        # a,s,v,y,z alone are simple characters
        if shortcut in ["-A", "-S", "-V", "-Y", "-Z"] then shortcut = "-other"

        # for tests and check the key and caracter numbers :
        # console.clear()
        # console.log '__keyPressListener____________________________'
        # console.log e
        # console.log "ctrl #{e.ctrlKey}; Alt #{e.altKey}; Shift #{e.shiftKey}; which #{e.which}; keyCode #{e.keyCode}"
        # console.log "metaKeyStrokesCode:'#{metaKeyStrokesCode} keyStrokesCode:'#{keyStrokesCode}'"

        # 2- manage the newPosition flag
        #    newPosition == true if the position of carret or selection has been
        #    modified with keyboard or mouse.
        #    If newPosition == true, then the selection must be "normalized" :
        #       - carret must be in a span
        #       - selection must start and end in a span

        # 2.1- Set a flag if the user moved the carret with keyboard
        if keyStrokesCode in ["left","up","right","down","pgUp","pgDwn","end",
                              "home"] and 
                              shortcut not in ['CtrlShift-down','CtrlShift-up']
            @newPosition = true
            $("#editorPropertiesDisplay").text("newPosition = true")
            
        #if there was no keyboard move action but the previous action was a move
        # then "normalize" the selection
        else
            if @newPosition
                @newPosition = false
                # TODO: following line is just for test, must be somewhere else.
                $("#editorPropertiesDisplay").text("newPosition = false")
                
                sel = @getEditorSelection()
                # if sthg is selected
                num = sel.rangeCount
                if num > 0
                    # for each selected area
                    for i in [0..num-1]
                        range = sel.getRangeAt(i)
                        @_normalize(range)
                        
        # 4- the current selection is initialized on each keypress
        this.currentSel = null
  
        # Record last key pressed and eventually update the history
        if @_lastKey != shortcut and shortcut in ["-tab", "-return", "-backspace", "-suppr", "CtrlShift-down", "CtrlShift-up", "Ctrl-C", "Shift-tab", "-space", "-other"]
            @_addHistory()
            
        @_lastKey = shortcut
                 
        # 5- launch the action corresponding to the pressed shortcut
        switch shortcut
            # RETURN
            when "-return"
                @_return()
                e.preventDefault()
                #@_updateDeepest()
            
            # TAB
            when "-tab"
                @tab()
                e.preventDefault()
                #@_updateDeepest()
            
            # BACKSPACE
            when "-backspace"
                @_backspace(e)
                #@_updateDeepest()
            
            # SUPPR
            when "-suppr"
                @_suppr(e)
                #@_updateDeepest()

            # CTRL SHIFT DOWN
            when "CtrlShift-down"
                @_moveLinesDown()
                e.preventDefault()

            # CTRL SHIFT UP
            when "CtrlShift-up"
                @_moveLinesUp()
                e.preventDefault()

            # SHIFT TAB
            when "Shift-tab"
                @shiftTab()
                e.preventDefault()
                #@_updateDeepest()
            
            # TOGGLE LINE TYPE (Alt + a)                  
            when "Alt-A"
                @_toggleLineType()
                e.preventDefault()
            
            # PASTE (Ctrl + v)                  
            when "Ctrl-V"
                true
                #@_updateDeepest()
            
            # SAVE (Ctrl + s)                  
            when "Ctrl-S"
                # TODO
                # console.log "TODO : SAVE"
                e.preventDefault()

            # UNDO (Ctrl + z)
            when "Ctrl-Z"
                e.preventDefault()
                @unDo()
                
            # REDO (Ctrl + y)
            when "Ctrl-Y"
                e.preventDefault()
                @reDo()

            

    ### ------------------------------------------------------------------------
    # Manage deletions when suppr key is pressed
    ###
    #
    # TODO: bug: a suppr operated before an empty line removes the <br> label
    _suppr : (e) ->
        @_findLinesAndIsStartIsEnd()
        sel = this.currentSel

        startLine = sel.startLine
        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed
            # 1.1 caret is at the end of the line
            if sel.rangeIsEndLine
                # if there is a next line : modify the selection to make
                # a multiline deletion
                if startLine.lineNext != null
                    sel.range.setEndBefore(startLine.lineNext.line$[0].firstChild)
                    sel.endLine = startLine.lineNext
                    @_deleteMultiLinesSelections()
                    e.preventDefault()
                # if there is no next line :
                # no modification, just prevent default action
                else
                    e.preventDefault()
            # 1.2 caret is in the middle of the line : nothing to do
            # else

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            sel.range.deleteContents()
            e.preventDefault()

        # 3- Case of a multi lines selection
        else
            @_deleteMultiLinesSelections()
            e.preventDefault()


    ### ------------------------------------------------------------------------
    #  Manage deletions when backspace key is pressed
    ###
    _backspace : (e) ->
        @_findLinesAndIsStartIsEnd()
        sel = this.currentSel
        startLine = sel.startLine

        # 1- Case of a caret "alone" (no selection)
        if sel.range.collapsed
            # 1.1 caret is at the beginning of the line
            if sel.rangeIsStartLine
                # if there is a previous line : modify the selection to make
                # a multiline deletion
                if startLine.linePrev != null
                    sel.range.setStartBefore(startLine.linePrev.line$[0].lastChild)
                    sel.startLine = startLine.linePrev
                    @_deleteMultiLinesSelections()
                    e.preventDefault()
                # if there is no previous line :
                # no modification, just prevent default action
                else
                    e.preventDefault()
            # 1.2 caret is in the middle of the line : nothing to do
            # else

        # 2- Case of a selection contained in a line
        else if sel.endLine == startLine
            sel.range.deleteContents()
            e.preventDefault()

        # 3- Case of a multi lines selection
        else
            @_deleteMultiLinesSelections()
            e.preventDefault()



    ### ------------------------------------------------------------------------
    #  Turn selected lines in a title List (Th)
    ###
    titleList : () ->
        # 1- Variables
        #sel                = rangy.getIframeSelection(@editorIframe)
        sel                 = @getEditorSelection()
        range              = sel.getRangeAt(0)
        startContainer     = range.startContainer
        endContainer       = range.endContainer
        initialStartOffset = range.startOffset
        initialEndOffset   = range.endOffset
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        startDiv = startContainer
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        endDiv = endContainer
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        endDivID = endDiv.id
        loop
            @_line2titleList(line)
            if line.lineID == endDivID
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    #  Turn a given line in a title List Line (Th)
    ###
    _line2titleList : (line)->
        if line.lineType != 'Th'
            if line.lineType[0] == 'L'
                line.lineType = 'Tu'
                line.lineDepthAbs += 1    
            @_titilizeSiblings(line)
            parent1stSibling = @_findParent1stSibling(line)
            while parent1stSibling!=null and parent1stSibling.lineType != 'Th'
                @_titilizeSiblings(parent1stSibling)
                parent1stSibling = @_findParent1stSibling(parent1stSibling)


    ### ------------------------------------------------------------------------
    # turn in Th or Lh of the siblings of line (and line itself of course)
    # the children are note modified
    ### 
    _titilizeSiblings : (line) ->
        lineDepthAbs = line.lineDepthAbs
        # 1- transform all its next siblings in Th
        l = line
        while l!=null and l.lineDepthAbs >= lineDepthAbs
            if l.lineDepthAbs == lineDepthAbs
                switch l.lineType 
                    when 'Tu','To'
                        l.line$.prop("class","Th-#{lineDepthAbs}")
                        l.lineType = 'Th'
                        l.lineDepthRel = 0
                    when 'Lu','Lo'
                        l.line$.prop("class","Lh-#{lineDepthAbs}")
                        l.lineType = 'Lh'
                        l.lineDepthRel = 0
            l=l.lineNext
        # 2- transform all its previous siblings in Th
        l = line.linePrev 
        while l!=null and l.lineDepthAbs >= lineDepthAbs
            if l.lineDepthAbs == lineDepthAbs
                switch l.lineType
                    when 'Tu','To'
                        l.line$.prop("class","Th-#{lineDepthAbs}")
                        l.lineType = 'Th'
                        l.lineDepthRel = 0
                    when 'Lu','Lo'
                        l.line$.prop("class","Lh-#{lineDepthAbs}")
                        l.lineType = 'Lh'
                        l.lineDepthRel = 0
            l=l.linePrev
        return true


    ### ------------------------------------------------------------------------
    #  Turn selected lines in a Marker List
    ###
    markerList : (l) ->
        # 1- Variables
        if l? 
            startDivID = l.lineID
            endLineID  = startDivID
        else
            range = @getEditorSelection().getRangeAt(0)
            initialStartOffset = range.startOffset
            initialEndOffset   = range.endOffset
            # 2- find first and last div corresponding to the 1rst and
            #    last selected lines
            startDiv = range.startContainer
            if startDiv.nodeName != "DIV"
                startDiv = $(startDiv).parents("div")[0]
            startDivID =  startDiv.id
            endDiv = range.endContainer
            if endDiv.nodeName != "DIV"
                endDiv = $(endDiv).parents("div")[0]
            endLineID = endDiv.id
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDivID]
        loop
            switch line.lineType
                when 'Th'
                    lineTypeTarget = 'Tu'
                    # transform all next Th & Lh siblings in Tu & Lu
                    l = line.lineNext
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        switch l.lineType
                            when 'Th'
                                l.line$.prop("class","Tu-#{l.lineDepthAbs}")
                                l.lineType = 'Tu'
                                l.lineDepthRel = @_findDepthRel(l)
                            when 'Lh'
                                l.line$.prop("class","Lu-#{l.lineDepthAbs}")
                                l.lineType = 'Lu'
                                l.lineDepthRel = @_findDepthRel(l)
                        l=l.lineNext
                    # transform all previous Th &vLh siblings in Tu & Lu
                    l = line.linePrev
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        switch l.lineType
                            when 'Th'
                                l.line$.prop("class","Tu-#{l.lineDepthAbs}")
                                l.lineType = 'Tu'
                                l.lineDepthRel = @_findDepthRel(l)
                            when 'Lh'
                                l.line$.prop("class","Lu-#{l.lineDepthAbs}")
                                l.lineType = 'Lu'
                                l.lineDepthRel = @_findDepthRel(l)
                        l=l.linePrev
                when 'Lh', 'Lu'
                    # remember : the default indentation action is to make 
                    # a marker list, that's why it works here.
                    @tab(line) 
                else
                    lineTypeTarget = false
            # TODO: à supprimer en mettant commençant les boucles par la ligne elle meme et non la suivante
            if lineTypeTarget 
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endLineID
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    # Calculates the relative depth of the line
    #   usage   : cycle : Tu => To => Lx => Th
    #   param   : line : the line we want to find the relative depth
    #   returns : a number
    # 
    ###
    _findDepthRel : (line) ->
        if line.lineDepthAbs == 1
            if line.lineType[1] == "h"
                return 0
            else
                return 1
        else 
            linePrev = line.linePrev
            while linePrev!=null and linePrev.lineDepthAbs >= line.lineDepthAbs
                linePrev = linePrev.linePrev
            if linePrev != null
                return linePrev.lineDepthRel+1
            else
                return 0


    ### ------------------------------------------------------------------------
    # Toggle line type
    #   usage : cycle : Tu => To => Lx => Th
    #   param :
    #       e = event
    ###
    _toggleLineType : () ->
        # 1- Variables
        #sel                = rangy.getIframeSelection(@editorIframe)
        sel                = @getEditorSelection()
        range              = sel.getRangeAt(0)
        startContainer     = range.startContainer
        endContainer       = range.endContainer
        initialStartOffset = range.startOffset
        initialEndOffset   = range.endOffset
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        startDiv = startContainer
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        endDiv = endContainer
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu' # can be turned in a Th only if his parent is a Th
                    lineTypeTarget = 'Th'
                    # transform all its siblings in Th
                    l = line.lineNext 
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Tu'
                                l.line$.prop("class","Th-#{line.lineDepthAbs}")
                                l.lineType = 'Th'
                            else
                                l.line$.prop("class","Lh-#{line.lineDepthAbs}")
                                l.lineType = 'Lh'
                        l=l.lineNext
                    l = line.linePrev 
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Tu'
                                l.line$.prop("class","Th-#{line.lineDepthAbs}")
                                l.lineType = 'Th'
                            else
                                l.line$.prop("class","Lh-#{line.lineDepthAbs}")
                                l.lineType = 'Lh'
                        l=l.linePrev

                when 'Th'
                    lineTypeTarget = 'Tu'
                    # transform all its siblings in Tu
                    l = line.lineNext
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Th'
                                l.line$.prop("class","Tu-#{line.lineDepthAbs}")
                                l.lineType = 'Tu'
                            else
                                l.line$.prop("class","Lu-#{line.lineDepthAbs}")
                                l.lineType = 'Lu'
                        l=l.lineNext
                    l = line.linePrev
                    while l!=null and l.lineDepthAbs >= line.lineDepthAbs
                        if l.lineDepthAbs == line.lineDepthAbs
                            if l.lineType == 'Th'
                                l.line$.prop("class","Tu-#{line.lineDepthAbs}")
                                l.lineType = 'Tu'
                            else
                                l.line$.prop("class","Lu-#{line.lineDepthAbs}")
                                l.lineType = 'Lu'
                        l=l.linePrev
                # when 'Lh'
                #     lineTypeTarget = 'Th'
                # when 'Lu'
                #     lineTypeTarget = 'Tu'
                else
                    lineTypeTarget = false
            if lineTypeTarget 
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endDiv.id
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    # tab keypress
    #   l = optional : a line to indent. If none, the selection will be indented
    ###
    tab :  (l) ->
        # 1- Variables
        if l? 
            startDiv = l.line$[0]
            endDiv   = startDiv
        else
            #sel      = rangy.getIframeSelection(@editorIframe)
            sel                = @getEditorSelection()
            range    = sel.getRangeAt(0)
            startDiv = range.startContainer
            endDiv   = range.endContainer
       
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        # 3- loop on each line between the firts and last line selected
        # TODO : deal the case of a multi range (multi selections). 
        #        Currently only the first range is taken into account.
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu','Th'
                    # find previous sibling to check if a tab is possible.
                    linePrevSibling = @_findPrevSibling(line)
                    if linePrevSibling == null
                        isTabAllowed=false
                    else 
                        isTabAllowed=true
                        # determine new lineType
                        if linePrevSibling.lineType == 'Th'
                            lineTypeTarget = 'Lh'
                        else 
                            if linePrevSibling.lineType == 'Tu'
                                lineTypeTarget = 'Lu'
                            else
                                lineTypeTarget = 'Lo'
                            if line.lineType == 'Th'
                                # in case of a Th => Lx then all the following 
                                # siblings must be turned to Tx and Lh into Lx
                                # first we must find the previous sibling line                                
                                # linePrevSibling = @_findPrevSibling(line)
                                # linePrev = line.linePrev
                                # while linePrev.lineDepthAbs > firstChild
                                #     textContent
                                lineNext = line.lineNext
                                while lineNext != null and lineNext.lineDepthAbs > line.lineDepthAbs
                                    switch lineNext.lineType
                                        when 'Th'
                                            lineNext.lineType = 'Tu'
                                            line.line$.prop("class","Tu-#{lineNext.lineDepthAbs}")
                                            nextLineType = prevTxType
                                        when 'Tu'
                                            nextLineType = 'Lu'
                                        when 'To'
                                            nextLineType = 'Lo'
                                        when 'Lh'
                                            lineNext.lineType = nextLineType
                                            line.line$.prop("class","#{nextLineType}-#{lineNext.lineDepthAbs}")
                when 'Lh', 'Lu', 'Lo'
                    # TODO : if there are new siblings, the target type must be 
                    # the one of those, otherwise Tu is default.
                    lineNext = line.lineNext
                    lineTypeTarget = null
                    while lineNext != null and lineNext.lineDepthAbs >= line.lineDepthAbs
                        if lineNext.lineDepthAbs != line.lineDepthAbs + 1
                            lineNext = lineNext.lineNext
                        else
                            lineTypeTarget = lineNext.lineType
                            lineNext=null
                    if lineTypeTarget == null
                        linePrev = line.linePrev
                        while linePrev != null and linePrev.lineDepthAbs >= line.lineDepthAbs
                            if linePrev.lineDepthAbs==line.lineDepthAbs + 1
                                lineTypeTarget = linePrev.lineType
                                linePrev=null
                            else
                                linePrev = linePrev.linePrev
                    if lineTypeTarget == null
                        isTabAllowed       = true
                        lineTypeTarget     = 'Tu'
                        line.lineDepthAbs += 1
                        line.lineDepthRel += 1
                    else
                        if lineTypeTarget == 'Th'
                            isTabAllowed       = true
                            line.lineDepthAbs += 1
                            line.lineDepthRel  = 0
                        if lineTypeTarget == 'Tu' or  lineTypeTarget == 'To'
                            isTabAllowed       = true
                            line.lineDepthAbs += 1
                            line.lineDepthRel += 1
            if isTabAllowed
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endLineID
                break
            else 
                line = line.lineNext


    ### ------------------------------------------------------------------------
    # shift + tab keypress
    #   myRange = if defined, refers to a specific region to untab
    ###
    shiftTab : (myRange) ->

        # 1- Variables
        if myRange?
            range = myRange
        else
            #sel   = rangy.getIframeSelection(@editorIframe)
            sel                = @getEditorSelection()
            range = sel.getRangeAt(0)
            
        startDiv           = range.startContainer
        endDiv             = range.endContainer
        initialStartOffset = range.startOffset
        initialEndOffset   = range.endOffset
        
        # 2- find first and last div corresponding to the 1rst and
        #    last selected lines
        if startDiv.nodeName != "DIV"
            startDiv = $(startDiv).parents("div")[0]
        if endDiv.nodeName != "DIV"
            endDiv = $(endDiv).parents("div")[0]
        endLineID = endDiv.id
        
        # 3- loop on each line between the firts and last line selected
        line = @_lines[startDiv.id]
        loop
            switch line.lineType
                when 'Tu','Th','To'
                    # find the closest parent to choose the new lineType.
                    parent = line.linePrev
                    while parent != null and parent.lineDepthAbs >= line.lineDepthAbs
                        parent = parent.linePrev
                    if parent != null
                        isTabAllowed   = true
                        lineTypeTarget = parent.lineType
                        lineTypeTarget = "L" + lineTypeTarget.charAt(1)
                        line.lineDepthAbs -= 1
                        line.lineDepthRel -= parent.lineDepthRel
                        # if lineNext is a Lx, then it must be turned in a Tx
                        if line.lineNext? and line.lineNext.lineType[0]=='L'
                            nextL = line.lineNext
                            nextL.lineType='T'+nextL.lineType[1] 
                            nextL.line$.prop('class',"#{nextL.lineType}-#{nextL.lineDepthAbs}")
                    else 
                        isTabAllowed = false
                when 'Lh'
                    isTabAllowed=true
                    lineTypeTarget     = 'Th'
                when 'Lu'
                    isTabAllowed=true
                    lineTypeTarget     = 'Tu'
                when 'Lo'
                    isTabAllowed=true
                    lineTypeTarget     = 'To'
            if isTabAllowed
                line.line$.prop("class","#{lineTypeTarget}-#{line.lineDepthAbs}")
                line.lineType = lineTypeTarget
            if line.lineID == endDiv.id
                break
            else 
                line = line.lineNext

    ### ------------------------------------------------------------------------
    # return keypress
    #   e = event
    ###
    _return : () ->
        @_findLinesAndIsStartIsEnd()
        currSel   = this.currentSel
        startLine = currSel.startLine
        endLine   = currSel.endLine

        console.log currSel
        
        # 1- Delete the selections so that the selection is collapsed
        if currSel.range.collapsed
            
        else if endLine == startLine
            currSel.range.deleteContents()
        else
            @_deleteMultiLinesSelections()
            @_findLinesAndIsStartIsEnd()
            currSel   = this.currentSel
            startLine = currSel.startLine
       
        # 2- Caret is at the end of the line
        if currSel.rangeIsEndLine
            newLine = @_insertLineAfter (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
            )
            # Position caret
            range4sel = rangy.createRange()
            range4sel.collapseToPoint(newLine.line$[0].firstChild,0)
            currSel.sel.setSingleRange(range4sel)

        # 3- Caret is at the beginning of the line
        else if currSel.rangeIsStartLine
            newLine = @_insertLineBefore (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
            )
            # Position caret
            range4sel = rangy.createRange()
            range4sel.collapseToPoint(startLine.line$[0].firstChild,0)
            currSel.sel.setSingleRange(range4sel)

        # 4- Caret is in the middle of the line
        else                     
            # Deletion of the end of the original line
            currSel.range.setEndBefore( startLine.line$[0].lastChild )
            endOfLineFragment = currSel.range.extractContents()
            currSel.range.deleteContents()
            # insertion
            newLine = @_insertLineAfter (
                sourceLine         : startLine
                targetLineType     : startLine.lineType
                targetLineDepthAbs : startLine.lineDepthAbs
                targetLineDepthRel : startLine.lineDepthRel
                fragment           : endOfLineFragment
            )
            # Position caret
            range4sel = rangy.createRange()
            console.log newLine.line$[0]
            #range4sel.collapseToPoint(newLine.line$[0].firstChild.childNodes[0],0)
            range4sel.collapseToPoint(newLine.line$[0].firstChild,0)
            
            currSel.sel.setSingleRange(range4sel)
            this.currentSel = null



    ### ------------------------------------------------------------------------
    # find the sibling line of the parent of line that is the first of the list
    # ex :
    #   . Sibling1 <= _findParent1stSibling(line)
    #   . Sibling2
    #   . Parent
    #      . child1
    #      . line     : the line in argument
    # returns null if no previous sibling, the line otherwise
    # the sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
    ### 
    _findParent1stSibling : (line) ->
        lineDepthAbs = line.lineDepthAbs
        linePrev = line.linePrev
        if linePrev == null
            return line
        if lineDepthAbs <= 2
            # in the 2 first levels the answer is _firstLine
            while linePrev.linePrev != null
                linePrev = linePrev.linePrev
            return linePrev
        else
            while linePrev != null and linePrev.lineDepthAbs > (lineDepthAbs - 2)
                linePrev = linePrev.linePrev
            return linePrev.lineNext


    ### ------------------------------------------------------------------------
    # find the previous sibling line.
    # returns null if no previous sibling, the line otherwise
    # the sibling is a title (Th, Tu or To), not a line (Lh nor Lu nor Lo)
    ###
    _findPrevSibling : (line)->
        lineDepthAbs = line.lineDepthAbs
        linePrevSibling = line.linePrev
        if linePrevSibling == null
            # nothing to do if first line
            return null
        else if linePrevSibling.lineDepthAbs < lineDepthAbs
            # If AbsDepth of previous line is lower : we are on the first
            # line of a list of paragraphes, there is no previous sibling
            return null
        else
            while linePrevSibling.lineDepthAbs > lineDepthAbs
                linePrevSibling = linePrevSibling.linePrev
            while linePrevSibling.lineType[0] == 'L'
                linePrevSibling = linePrevSibling.linePrev
            return linePrevSibling


    ### ------------------------------------------------------------------------
    # Delete the user multi line selection
    #
    # prerequisite : at least 2 different lines must be selected
    # parameters   : startLine = first line to be deleted
    #                endLine   = last line to be deleted
    ###
    _deleteMultiLinesSelections : (startLine, endLine) ->
        # If startLine and endLine are specified, lines included between these
        # two are removed. This is useful when making line's depth inheritance
        
        # true when the caret needs to be repositioned after deletion
        replaceCaret = true

        # 0 - variables
        if startLine != undefined
            replaceCaret = false
            range = rangy.createRange()
            
            # If the very first line must be deleted
            if startLine == null
                startLine = endLine
                endLine = endLine.lineNext
                @_putStartOnStart(range, startLine.line$[0].firstElementChild)
                endLine.line$.prepend '<span></span>'
                @_putEndOnStart(range, endLine.line$[0].firstElementChild)
            else
                startNode = startLine.line$[0].lastElementChild.previousElementSibling
                endNode = endLine.line$[0].lastElementChild.previousElementSibling
                range.setStartAfter(startNode,0)
                range.setEndAfter(endNode,0)
        else
            @_findLines()
            range = this.currentSel.range
            startContainer = range.startContainer
            startOffset    = range.startOffset
            startLine      = this.currentSel.startLine
            endLine        = this.currentSel.endLine
            
        endLineDepthAbs   = endLine.lineDepthAbs
        startLineDepthAbs = startLine.lineDepthAbs
        deltaDepth        = endLineDepthAbs - startLineDepthAbs

        # 1- copy the end of endLine in a fragment
        range4fragment = rangy.createRangyRange()
        range4fragment.setStart(range.endContainer, range.endOffset)
        range4fragment.setEndAfter(endLine.line$[0].lastChild)
        endOfLineFragment = range4fragment.cloneContents()

        # 2- adapt the type of endLine and of its children to startLine 
        # the only useful case is when endLine must be changed from Th to Tu or To
        if endLine.lineType[1] == 'h' and startLine.lineType[1] != 'h'
            if endLine.lineType[0] == 'L'
                endLine.lineType = 'T' + endLine.lineType[1]
                endLine.line$.prop("class","#{endLine.lineType}-#{endLine.lineDepthAbs}")
            @markerList(endLine)

        # 3- delete lines
        range.deleteContents()

        # 4- append fragment and delete endLine
        if startLine.line$[0].lastChild.nodeName == 'BR'
            startLine.line$[0].removeChild( startLine.line$[0].lastChild)
        startFrag = endOfLineFragment.childNodes[0]
        myEndLine = startLine.line$[0].lastElementChild
        # if startFrag et myEndLine are SPAN and they both have the same class
        # then we concatenate both
        if (startFrag.tagName == myEndLine.tagName == 'SPAN') and 
        (startFrag.className == myEndLine.className)

            startOffset = $(myEndLine).text().length
            newText = $(myEndLine).text() + $(startFrag).text()
            $(myEndLine).text( newText )
            startContainer = myEndLine.firstChild
            
            l=1
            while l < endOfLineFragment.childNodes.length
                $(endOfLineFragment.childNodes[l]).appendTo startLine.line$
                l++
        else
            startLine.line$.append( endOfLineFragment )
            
        startLine.lineNext = endLine.lineNext
        if endLine.lineNext != null
            endLine.lineNext.linePrev=startLine
        endLine.line$.remove()
        delete this._lines[endLine.lineID]

        # 5- adapt the depth of the children and following siblings of end line
        #    in case the depth delta between start and end line is
        #    greater than 0, then the structure is not correct : we reduce
        #    the depth of all the children and siblings of endLine.
        line = startLine.lineNext
        if line != null
            deltaDepth1stLine = line.lineDepthAbs - startLineDepthAbs
            if deltaDepth1stLine >= 1 
                while line!= null and line.lineDepthAbs >= endLineDepthAbs
                    newDepth = line.lineDepthAbs - deltaDepth
                    line.lineDepthAbs = newDepth
                    line.line$.prop("class","#{line.lineType}-#{newDepth}")
                    line = line.lineNext
                    
        # 6- adapt the type of the first line after the children and siblings of
        #    end line. Its previous sibling or parent might have been deleted, 
        #    we then must find its new one in order to adapt its type.
        if line != null
            # if the line is a line (Lx), then make it "independant"
            # by turning it in a Tx
            if line.lineType[0] == 'L'
                line.lineType = 'T' + line.lineType[1]
                line.line$.prop("class","#{line.lineType}-#{line.lineDepthAbs}")
            # find the previous sibling, adjust type to its type.
            firstLineAfterSiblingsOfDeleted = line
            depthSibling = line.lineDepthAbs
            
            line = line.linePrev
            while line != null and line.lineDepthAbs > depthSibling
                line = line.linePrev
            if line != null
                prevSiblingType = line.lineType
                if firstLineAfterSiblingsOfDeleted.lineType!=prevSiblingType
                    if prevSiblingType[1]=='h'
                        @_line2titleList(firstLineAfterSiblingsOfDeleted)
                    else
                        @markerList(firstLineAfterSiblingsOfDeleted)

        # 7- position caret
        if replaceCaret
            range4caret = rangy.createRange()
            range4caret.collapseToPoint(startContainer, startOffset)
            this.currentSel.sel.setSingleRange(range4caret)
            this.currentSel = null
        # else
        #   do nothing
        
                
    ### ------------------------------------------------------------------------
    # Insert a line after a source line
    # p = 
    #     sourceLine         : line after which the line will be added
    #     fragment           : [optionnal] - an html fragment that will be added
    #     innerHTML          : [optionnal] - an html string that will be added
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineAfter : (p) ->
        @_highestId += 1
        lineID          = 'CNID_' + @_highestId
        if p.fragment? 
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
            newLine$.append( p.fragment )
            if newLine$[0].lastChild.nodeName != 'BR'
                newLine$.append('<br>')
        else if p.innerHTML?
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'>
                #{p.innerHTML}</div>")
            if newLine$[0].lastChild.nodeName != 'BR'
                newLine$.append('<br>')
        else
            newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
            newLine$.append( $('<span></span><br>') )
        sourceLine = p.sourceLine
        newLine$   = newLine$.insertAfter(sourceLine.line$)
        newLine    =  
            line$        : newLine$
            lineID       : lineID
            lineType     : p.targetLineType
            lineDepthAbs : p.targetLineDepthAbs
            lineDepthRel : p.targetLineDepthRel
            lineNext     : sourceLine.lineNext
            linePrev     : sourceLine
        @_lines[lineID] = newLine
        if sourceLine.lineNext != null
            sourceLine.lineNext.linePrev = newLine
        sourceLine.lineNext = newLine
        return newLine



    ### ------------------------------------------------------------------------
    # Insert a line before a source line
    # p = 
    #     sourceLine         : ID of the line before which a line will be added
    #     fragment           : [optionnal] - an html fragment that will be added
    #     targetLineType     : type of the line to add
    #     targetLineDepthAbs : absolute depth of the line to add
    #     targetLineDepthRel : relative depth of the line to add
    ###
    _insertLineBefore : (p) ->
        @_highestId += 1
        lineID = 'CNID_' + @_highestId
        newLine$ = $("<div id='#{lineID}' class='#{p.targetLineType}-#{p.targetLineDepthAbs}'></div>")
        if p.fragment? 
            newLine$.append( p.fragment )
            newLine$.append( $('<br>') )
        else
            newLine$.append( $('<span></span><br>') )
        sourceLine = p.sourceLine
        newLine$ = newLine$.insertBefore(sourceLine.line$)
        newLine = 
            line$        : newLine$
            lineID       : lineID
            lineType     : p.targetLineType
            lineDepthAbs : p.targetLineDepthAbs
            lineDepthRel : p.targetLineDepthRel
            lineNext     : sourceLine
            linePrev     : sourceLine.linePrev
        @_lines[lineID] = newLine
        if sourceLine.linePrev != null
            sourceLine.linePrev.lineNext = newLine
        sourceLine.linePrev=newLine
        return newLine


    ### ------------------------------------------------------------------------
    # Finds :
    #   First and last line of selection. 
    # Remark :
    #   Only the first range of the selections is taken into account.
    # Returns : 
    #   sel : the selection
    #   range : the 1st range of the selections
    #   startLine : the 1st line of the range
    #   endLine : the last line of the range
    ###
    _findLines : () ->
        if this.currentSel == null
            # 1- Variables
            #sel                = rangy.getIframeSelection(@editorIframe)
            sel                = @getEditorSelection()
            range              = sel.getRangeAt(0)
            startContainer     = range.startContainer
            endContainer       = range.endContainer
            initialStartOffset = range.startOffset
            initialEndOffset   = range.endOffset
            
            # 2- find endLine 
            # endContainer refers to a div of a line
            if endContainer.id? and endContainer.id.substr(0,5) == 'CNID_'  
                endLine = @_lines[ endContainer.id ]
            # means the range ends inside a div (span, textNode...)
            else   
                endLine = @_lines[ $(endContainer).parents("div")[0].id ]
            
            # 3- find startLine
            if startContainer.nodeName == 'DIV'
                # startContainer refers to a div of a line
                startLine = @_lines[ startContainer.id ]
            else   # means the range starts inside a div (span, textNode...)
                startLine = @_lines[ $(startContainer).parents("div")[0].id ]
            
            # 4- return
            return this.currentSel = 
                sel              : sel
                range            : range
                startLine        : startLine
                endLine          : endLine
                rangeIsStartLine : null
                rangeIsEndLine   : null


    ### ------------------------------------------------------------------------
    # Finds :
    #   first and last line of selection 
    #   wheter the selection starts at the beginning of startLine or not
    #   wheter the selection ends at the end of endLine or not
    # 
    # Remark :
    #   Only the first range of the selections is taken into account.
    #
    # Returns : 
    #   sel : the selection
    #   range : the 1st range of the selections
    #   startLine : the 1st line of the range
    #   endLine : the last line of the range
    #   rangeIsEndLine : true if the range ends at the end of the last line
    #   rangeIsStartLine : true if the range starts at the start of 1st line
    ###
    _findLinesAndIsStartIsEnd : () ->
        if this.currentSel == null
            
            # 1- Variables
            #sel                = rangy.getIframeSelection(@editorIframe)
            sel                = @getEditorSelection()
            range              = sel.getRangeAt(0)
            startContainer     = range.startContainer
            endContainer       = range.endContainer
            initialStartOffset = range.startOffset
            initialEndOffset   = range.endOffset
            
            # 2- find endLine and the rangeIsEndLine
            # endContainer refers to a div of a line
            if endContainer.id? and endContainer.id.substr(0,5) == 'CNID_'
                endLine = @_lines[ endContainer.id ]
                # rangeIsEndLine if endOffset points on the last node of the div
                # or on the one before the last which is a <br>
                rangeIsEndLine = ( endContainer.children.length-1==initialEndOffset ) or
                                 (endContainer.children[initialEndOffset].nodeName=="BR")
            # means the range ends inside a div (span, textNode...)
            else
                endLine = @_lines[ $(endContainer).parents("div")[0].id ]
                parentEndContainer = endContainer
                # rangeIsEndLine if the selection is at the end of the
                # endContainer and of each of its parents (this approach is more
                # robust than just considering that the line is a flat
                # succession of span : maybe one day there will be a table for
                # instance...)
                rangeIsEndLine = false
                # case of a textNode: it must have no nextSibling and offset must be its length
                if endContainer.nodeType == Node.TEXT_NODE
                    rangeIsEndLine = endContainer.nextSibling == undefined and
                                     initialEndOffset == endContainer.textContent.length
                # case of another node : it must be a br; or followed by a br
                #  and have maximal offset
                else
                    nextSibling    = endContainer.nextSibling
                    rangeIsEndLine = endContainer.nodeName=='BR' or
                                     (nextSibling.nodeName=='BR' and
                                     endContainer.childNodes.length==initialEndOffset)
                    #nextSibling    = endContainer.nextSibling
                    #rangeIsEndLine = (nextSibling == null or nextSibling.nodeName=='BR')
                    #(nextSibling == null or (initialEndOffset==parentEndContainer.textContent.length and nextSibling.nodeName=='BR'))
                    
                parentEndContainer = endContainer.parentNode
                while rangeIsEndLine and parentEndContainer.nodeName != "DIV"
                    nextSibling = parentEndContainer.nextSibling
                    #rangeIsEndLine = (nextSibling == null or nextSibling.nodeName=='BR')
                    rangeIsEndLine = endContainer.nodeName=='BR' or
                                     (nextSibling.nodeName=='BR' and
                                     endContainer.childNodes.length==initialEndOffset)
                    parentEndContainer = parentEndContainer.parentNode
            
            # 3- find startLine and rangeIsStartLine
            if startContainer.nodeName == 'DIV' # startContainer refers to a div of a line
                startLine = @_lines[ startContainer.id ]
                rangeIsStartLine = (initialStartOffset==0)
                 #if initialStartOffset==1 and startContainer.innerHTML=="<span></span><br>" # startContainer is the br after an empty span
                     #rangeIsStartLine = true
            else   # means the range starts inside a div (span, textNode...)
                startLine = @_lines[ $(startContainer).parents("div")[0].id ]
                rangeIsStartLine = (initialStartOffset==0)
                while rangeIsStartLine && parentEndContainer.nodeName != "DIV"
                    rangeIsStartLine = (parentEndContainer.previousSibling==null)
                    parentEndContainer = parentEndContainer.parentNode

            # Special case of an "empty" line (<span><""></span><br>)
            if endLine.line$[0].innerHTML == "<span></span><br>"
                rangeIsEndLine = true
            if startLine.line$[0].innerHTML == "<span></span><br>"
                rangeIsStartLine = true

            # 4- return
            return this.currentSel = 
                sel              : sel
                range            : range
                startLine        : startLine
                endLine          : endLine
                rangeIsStartLine : rangeIsStartLine
                rangeIsEndLine   : rangeIsEndLine
        # return [sel,range,endLine,rangeIsEndLine,startLine,rangeIsStartLine]



    ###  -----------------------------------------------------------------------
    # Parse a raw html inserted in the iframe in order to update the controler
    ###
    _readHtml : () ->
        linesDiv$    = @editorBody$.children()  # linesDiv$= $[Div of lines]
        # loop on lines (div) to initialise the editor controler
        lineDepthAbs = 0
        lineDepthRel = 0
        lineID       = 0
        @_lines      = {}
        linePrev     = null
        lineNext     = null
        for htmlLine in linesDiv$
            htmlLine$ = $(htmlLine)
            lineClass = htmlLine$.attr('class') ? ""
            lineClass = lineClass.split('-')
            lineType  = lineClass[0]
            if lineType != ""
                lineDepthAbs_old = lineDepthAbs
                # hypothesis : _readHtml is called only on an html where 
                #              class="Tu-xx" where xx is the absolute depth
                lineDepthAbs     = +lineClass[1] 
                DeltaDepthAbs    = lineDepthAbs - lineDepthAbs_old
                lineDepthRel_old = lineDepthRel
                if lineType == "Th"
                    lineDepthRel = 0
                else 
                    lineDepthRel = lineDepthRel_old + DeltaDepthAbs
                lineID=(parseInt(lineID,10)+1)
                lineID_st = "CNID_"+lineID
                htmlLine$.prop("id",lineID_st)
                lineNew = 
                    line$        : htmlLine$
                    lineID       : lineID_st
                    lineType     : lineType
                    lineDepthAbs : lineDepthAbs
                    lineDepthRel : lineDepthRel
                    lineNext     : null
                    linePrev     : linePrev
                if linePrev != null then linePrev.lineNext = lineNew
                linePrev = lineNew
                @_lines[lineID_st] = lineNew
        @_highestId = lineID



    ### ------------------------------------------------------------------------
    # LINES MOTION MANAGEMENT
    # 
    # Functions to perform the motion of an entire block of lines
    # TODO: bug: wrong selection restorations when moving the second line up
    # TODO: correct re-insertion of the line swapped with the block
    ####
    _moveLinesDown : () ->
        
        # 0 - Set variables with informations on the selected lines
        sel = @_findLines()
        lineStart = sel.startLine
        lineEnd   = sel.endLine
        linePrev  = lineStart.linePrev
        lineNext  = lineEnd.lineNext
            
        # if it isnt the last line
        if lineNext != null
            
            # 1 - save lineNext
            cloneLine =
                line$        : lineNext.line$.clone()
                lineID       : lineNext.lineID
                lineType     : lineNext.lineType
                lineDepthAbs : lineNext.lineDepthAbs
                lineDepthRel : lineNext.lineDepthRel
                linePrev     : lineNext.linePrev
                lineNext     : lineNext.lineNext

            #savedSel = rangy.saveSelection(rangy.dom.getIframeWindow @editorIframe)
            savedSel = @saveEditorSelection()
                
            # 2 - Delete the lowerline content then restore initial selection
            @_deleteMultiLinesSelections(lineEnd, lineNext)
            rangy.restoreSelection(savedSel)
            
            # 3 - Restore the lowerline
            lineNext = cloneLine
            @_lines[lineNext.lineID] = lineNext
            
            # 4 - Modify the linking
            lineNext.linePrev = linePrev
            lineStart.linePrev = lineNext
            if lineNext.lineNext != null
                lineNext.lineNext.linePrev = lineEnd
            lineEnd.lineNext = lineNext.lineNext
            lineNext.lineNext = lineStart
            if linePrev != null
                linePrev.lineNext = lineNext
                
            # 5 - Modify the DOM
            lineStart.line$.before(lineNext.line$)
            
            # 6-Re-insert properly lineNext before the start of the moved block
            if linePrev == null then return
            #6.1 if the swapped line is less indented than the block's prev line
            if lineNext.lineDepthAbs <= linePrev.lineDepthAbs
                # create a range to select the block to untab (several times)
                line = lineNext
                while (line.lineNext!=null and line.lineNext.lineDepthAbs>lineNext.lineDepthAbs)
                    line = line.lineNext
                if line.lineNext != null
                    line = line.lineNext
                myRange = rangy.createRange()
                myRange.setStart(lineNext.lineNext.line$[0], 0)
                myRange.setEnd(line.line$[0], 0)
                # Now we untab the block selected.
                numOfUntab=lineNext.lineNext.lineDepthAbs-lineStart.lineDepthAbs
                if lineNext.lineNext.lineType[0]=='T'
                    # if linePrev is a 'T' and a 'T' follows, one untab less
                    if lineStart.lineType[0]=='T'
                        numOfUntab -= 1
                    # if linePrev is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1
                
                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1
                    
            #6.2 if the swapped line is more indented than the block's prev line
            else
                # untab the line (several times)
                myRange = rangy.createRange()
                myRange.setStart(lineNext.line$[0], 0)
                myRange.setEnd(lineNext.line$[0], 0)
                numOfUntab = lineStart.lineDepthAbs - lineNext.lineDepthAbs
                
                if lineStart.lineType[0]=='T'
                    # if lineEnd is a 'T' and a 'T' follows, one untab less
                    if linePrev.lineType[0]=='T'
                        numOfUntab -= 1
                    # if lineEnd is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1
                
                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1 


    _moveLinesUp : () ->
        
        # 0 - Set variables with informations on the selected lines
        sel = @_findLines()
        lineStart = sel.startLine
        lineEnd   = sel.endLine
        linePrev  = lineStart.linePrev
        lineNext  = lineEnd.lineNext
 
        # if it isnt the first line
        if linePrev != null
            
            # 0 - set boolean indicating if we are treating the second line
            secondL = (linePrev.linePrev == null)
                        
            # 1 - save linePrev
            cloneLine =
                line$        : linePrev.line$.clone()
                lineID       : linePrev.lineID
                lineType     : linePrev.lineType
                lineDepthAbs : linePrev.lineDepthAbs
                lineDepthRel : linePrev.lineDepthRel
                linePrev     : linePrev.linePrev
                lineNext     : linePrev.lineNext

            #savedSel = rangy.saveSelection(rangy.dom.getIframeWindow @editorIframe)
            savedSel = @saveEditorSelection()
            
            # 2 - Delete the upperline content then restore initial selection
            @_deleteMultiLinesSelections(linePrev.linePrev, linePrev)
            rangy.restoreSelection(savedSel)

            # 3 - Restore the upperline
            # 3.1 - if secondL is true, line objects must be fixed
            if secondL
                # remove the hidden element inserted by deleteMultiLines
                $(linePrev.line$[0].firstElementChild).remove()
                # add the missing BR
                linePrev.line$.append '<br>'
                lineStart.line$ = linePrev.line$
                lineStart.line$.attr('id', lineStart.lineID)
                @_lines[lineStart.lineID] = lineStart
                
            linePrev = cloneLine
            @_lines[linePrev.lineID] = linePrev

            # 4 - Modify the linking
            linePrev.lineNext = lineNext
            lineEnd.lineNext = linePrev
            if linePrev.linePrev != null
                linePrev.linePrev.lineNext = lineStart
            lineStart.linePrev = linePrev.linePrev
            linePrev.linePrev = lineEnd
            if lineNext != null
                lineNext.linePrev = linePrev
                
            # 5 - Modify the DOM
            lineEnd.line$.after(linePrev.line$)

            # 6 - Re-insert properly linePrev after the end of the moved block
            #6.1 if the swapped line is less indented than the block's last line
            if linePrev.lineDepthAbs <= lineEnd.lineDepthAbs
                # create a range to select the block to untab (several times)
                line = linePrev
                while (line.lineNext!=null and line.lineNext.lineDepthAbs>linePrev.lineDepthAbs)
                    line = line.lineNext
                if line.lineNext != null
                    line = line.lineNext
                myRange = rangy.createRange()
                myRange.setStart(linePrev.lineNext.line$[0], 0)
                myRange.setEnd(line.line$[0], 0)
                # Now we untab the block selected.
                numOfUntab = linePrev.lineNext.lineDepthAbs - linePrev.lineDepthAbs
                if linePrev.lineNext.lineType[0]=='T'
                    # if linePrev is a 'T' and a 'T' follows, one untab less
                    if linePrev.lineType[0]=='T'
                        numOfUntab -= 1
                    # if linePrev is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1
                
                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1
                    
            #6.2 if the swapped line is more indented than the block's last line
            else
                # untab the line (several times)
                myRange = rangy.createRange()
                myRange.setStart(linePrev.line$[0], 0)
                myRange.setEnd(linePrev.line$[0], 0)
                numOfUntab = linePrev.lineDepthAbs - lineEnd.lineDepthAbs
                
                if linePrev.lineType[0]=='T'
                    # if lineEnd is a 'T' and a 'T' follows, one untab less
                    if lineEnd.lineType[0]=='T'
                        numOfUntab -= 1
                    # if lineEnd is a 'L' and a 'T' follows, one untab more
                    else
                        numOfUntab += 1
                
                while numOfUntab >= 0
                    @shiftTab(myRange)
                    numOfUntab -= 1

    ### ------------------------------------------------------------------------
    #  HISTORY MANAGEMENT:
    # 1. _addHistory (Add html code and selection markers to the history)
    # 2. undoPossible (Return true only if unDo can be called)
    # 3. redoPossible (Return true only if reDo can be called)
    # 4. unDo (Undo the previous action)
    # 5. reDo ( Redo a undo-ed action)
    ###
    
    # Add html code and selection markers to the history
    _addHistory : () ->
        # 0 - mark selection
        #savedSel = rangy.saveSelection(rangy.dom.getIframeWindow @editorIframe)
        savedSel = @saveEditorSelection()
        @_history.historySelect.push savedSel

        # TODO: Following code does not work. Indeed it tries to get the
        #      position of @editorIframe.contentWindow's scrollbar but what we
        #      need is the position of the scrollbar which appears INSIDE the
        #      iframe's body. The code below always returns 0 because the window
        #      of the iframe actually never scrolls: no scrollbar is associated
        #      to this window.
        # -> solutions? set our own scrollbar's system
        #               find out how to get the browser's auto scrollbars
        #                 positions inside a DOM element (textarea for ex.)
        savedScroll = 
            xcoord: @editorBody$.scrollTop()
            ycoord: @editorBody$.scrollLeft()
            
        @_history.historyScroll.push savedScroll
        
        # 1- add the html content with markers to the history
        @_history.history.push @editorBody$.html()
        rangy.removeMarkers(savedSel)

        # 2 - update the index
        @_history.index = @_history.history.length-1
        
        # fire an event indicating history has changed
        $(@editorTarget).trigger jQuery.Event("onHistoryChanged")


    # Return true only if unDo can be called
    undoPossible : () ->
        return (@_history.index > 0)

    # Return true only if reDo can be called
    redoPossible : () ->
        return (@_history.index < @_history.history.length-2)
        
    # Undo the previous action
    unDo : () ->
        # if there is an action to undo
        if @undoPossible()
            
            # 0 - if we are in an unsaved state
            if @_history.index == @_history.history.length-1
                # save current state
                @_addHistory()
                # re-evaluate index
                @_history.index -= 1
                
            # 1 - restore html
            @editorBody$.html @_history.history[@_history.index]
            
            # 2 - restore selection
            savedSel = @_history.historySelect[@_history.index]
            rangy.restoreSelection(savedSel)
            savedSel.restored = false

            
            xcoord = @_history.historyScroll[@_history.index].xcoord
            ycoord = @_history.historyScroll[@_history.index].ycoord

            
            @editorBody$.scrollTop(xcoord)
            @editorBody$.scrollLeft(ycoord)

            # 7- position caret?
            # range4caret = rangy.createRange()
            # range4caret.collapseToPoint(startContainer, startOffset)
            # this.currentSel.sel.setSingleRange(range4caret)
            # this.currentSel = null
            
            # 3 - update the index
            @_history.index -= 1
        
    # Redo a undo-ed action
    reDo : () ->
        # if there is an action to redo
        if @redoPossible()
            
            # 0 - update the index
            @_history.index += 1
            
            # 1 - restore html
            @editorBody$.html @_history.history[@_history.index+1]
            
            # 2 - restore selection
            savedSel = @_history.historySelect[@_history.index+1]
            rangy.restoreSelection(savedSel)
            savedSel.restored = false


            xcoord = @_history.historyScroll[@_history.index+1].xcoord
            ycoord = @_history.historyScroll[@_history.index+1].ycoord
            
            @editorBody$.scrollTop(xcoord)
            @editorBody$.scrollLeft(ycoord)
            


    ### ------------------------------------------------------------------------
    # SUMMARY MANAGEMENT
    # 
    # initialization
    # TODO: avoid updating the summary too often
    #       it would be best to make the update faster (rather than reading
    #       every line)
    ###
    _initSummary : () ->
        summary = @editorBody$.children("#navi")
        if summary.length == 0
            summary = $ document.createElement('div')
            summary.attr('id', 'navi')
            summary.prependTo @editorBody$
        return summary
    ###
    # Summary upkeep
    ###
    _buildSummary : () ->
        summary = @initSummary()
        @editorBody$.children("#navi").children().remove()
        lines = @_lines
        for c of lines
            if (@editorBody$.children("#" + "#{lines[c].lineID}").length > 0 and lines[c].lineType == "Th")
                lines[c].line$.clone().appendTo summary



    ### ------------------------------------------------------------------------
    #  DECORATION FUNCTIONS (bold/italic/underlined/quote)
    #  TODO
    ###

    
    ### ------------------------------------------------------------------------
    #  PASTE MANAGEMENT
    # 0 - save selection
    # 1 - move the cursor into an invisible sandbox
    # 2 - redirect pasted content in this sandox
    # 3 - sanitize and adapt pasted content to the editor's format.....TODO
    # 4 - restore selection
    # 5 - insert cleaned content is behind the cursor position.........TODO
    ###
    paste : (event) ->
        # init the div where the paste will actualy accur. 
        mySandBox = @_initClipBoard()
        # save current selection 
        # TODO BJA : is it usefull ?? the range of the
        # selection should be enoght since there is no modification of the 
        # content during the paste in the clipboard
        # savedSel = @saveEditorSelection()
        @_findLinesAndIsStartIsEnd()
        # move carret into the sandbox
        range = rangy.createRange()
        range.selectNodeContents mySandBox
        #sel = rangy.getIframeSelection @editorIframe
        sel = @getEditorSelection()
        sel.setSingleRange range
        # check whether the browser is a Webkit or not
        if event and event.clipboardData and event.clipboardData.getData
            # Webkit: 1 - get data from clipboard
            #         2 - put data in the sandbox
            #         3 - clean the sandbox
            #         4 - cancel event (otherwise it pastes twice)
            if event.clipboardData.types == "text/html"
                mySandBox.innerHTML = event.clipboardData.getData('text/html');
            else if event.clipboardData.types == "text/plain"
                mySandBox.innerHTML = event.clipboardData.getData('text/plain');
            else
                mySandBox.innerHTML = ""
            @_waitForPasteData(mySandBox, @_processPaste)
            if event.preventDefault
                event.stopPropagation()
                event.preventDefault()
            return false
        else
            # not a Webkit: 1 - empty the sandBox
            #               2 - paste in sandBox
            #               3 - cleanup the sandBox
            mySandBox.innerHTML = ""
            @_waitForPasteData(mySandBox, @_processPaste)
            return true

    ###*
     * init the div where the browser will actualy paste.
     * @return {obj} a ref to the pasted content
    ###
    _initClipBoard : () ->
        clipboard = @editorBody$.children("#clipboard-sandbox")
        if clipboard.length == 0   # TODO BJA should be done once at initialisation of
            clipboard = $ document.createElement('div')
            # clipboard.attr('contenteditable', true)
            clipboard.attr('display', "none") # TODO BJA : this attributes doesn't exist : should be removed ?
            clipboard.html 'hello txt'
            clipboard.attr('id', "clipboard-sandbox")
            getOffTheScreen =
                left: 300  # -1000
                top : 10   # -1000
            clipboard.offset getOffTheScreen
            clipboard.prependTo @editorBody$
        return clipboard[0]
            
    _waitForPasteData : (sandbox, processpaste) ->
        ( waitforpastedata = (elem) ->
            if elem.childNodes and elem.childNodes.length > 0
                # again, something is missing during the restoration
                processpaste(sandbox)
                # rangy.restoreSelection(savedSel)
                # rangy.removeMarkers(savedSel)
            else
                that = {e: elem}
                that.callself = () ->
                    waitforpastedata that.e
                setTimeout(that.callself, 10) )(sandbox)
            
    _processPaste : (sandbox) =>
        pasteddata = sandbox.innerHTML
        console.log(pasteddata)
        sandbox.innerHTML = "" # comment for tests.

        # sanitize with node-validator 
        # (https://github.com/chriso/node-validator)
        # may be improved with google caja sanitizer :
        # http://code.google.com/p/google-caja/wiki/JsHtmlSanitizer
        str = sanitize(pasteddata).xss();
        sandbox.innerHTML = pasteddata
        # insert
        console.log "TTTTTTMMMMMMMRRRRRRRRRRRMMMMMOUOUOUUOOUZZ"
        console.log sandbox

        currSel = @currentSel
        frag = document.createDocumentFragment()
        dummyLine = 
            lineNext : null
            linePrev : null
            line$    : $("<div id='dummy' class='Tu-1'></div>")
        frag.appendChild(dummyLine.line$[0])

        # 
        domWalkContext = 
            absDepth           : currSel.startLine.lineDepthAbs,
            prevHxLevel        : null,
            prevCNLineAbsDepth : null, # previous Cozy Note Line Abs Depth
            lastAddedLine      : dummyLine
        htmlStr = @_domWalk(sandbox,domWalkContext)
        
        # delete dummy line from the fragment
        frag.removeChild(frag.firstChild)

        # delete the first range before insertion
        # @_findLinesAndIsStartIsEnd()
        startLine = currSel.startLine
        endLine   = currSel.endLine
        
        # 1- Delete the selections so that the selection is collapsed
        if currSel.range.collapsed
            
        else if endLine == startLine
            currSel.range.deleteContents()
        else
            @_deleteMultiLinesSelections()
            currSel   = @_findLinesAndIsStartIsEnd()
            startLine = currSel.startLine

        # 2- insert first line of the clipboard in the target line
        targetNode  = currSel.range.startContainer
        startOffset = currSel.range.startOffset
        i=0
        while i < frag.childNodes[0].childNodes.length-1
            elToInsert = frag.firstChild.childNodes[i]
            i +=1
            # targeNode is a TextNode or a SPAN
            # targetNode is a A
            
            # if targetNode & elToInsert are SPANs and both have 
            # the same class, then we concatenate them
            if (elToInsert.tagName == 'SPAN' ) and 
            (targetNode.tagName == 'SPAN') and
            (elToInsert.className == targetNode.className)
                targetText  = targetNode.textContent
                newText     = targetText.substr(0,startOffset)
                newText    += elToInsert.textContent
                newText    += targetText.substr(startOffset)
                targetNode.textContent = newText
                startOffset   += elToInsert.textContent.length

            # if targetNode & elToInsert are SPAN or TextNode and both have 
            # the same class, then we concatenate them
            else if (elToInsert.tagName=='SPAN' or elToInsert.nodeType==Node.TEXT_NODE) and
            (targetNode.tagName=='SPAN' or targetNode.nodeType==Node.TEXT_NODE )
                targetText = targetNode.textContent
                newText    = targetText.substr(0,startOffset)
                newText    += elToInsert.textContent
                newText    += targetText.substr(startOffset)
                targetNode.textContent = newText
                startOffset   += elToInsert.textContent.length
            else
                startLine.line$.append( endOfLineFragment )




        # 3- Insert the end of target line in the last line of frag
        # targetNode  = currSel.range.startContainer
        # startOffset = currSel.range.startOffset

        if targetNode.nodeType == Node.TEXT_NODE
            






        i=0
        while i < targetNode.childNodes.length-1
            elToInsert = frag.childNodes[0].childNodes[i]

        # remove the firstAddedLine from the fragment
        firstAddedLine = dummyLine.lineNext
        secondAddedLine = firstAddedLine.lineNext
        frag.removeChild(frag.firstChild)
        delete this._lines[firstAddedLine.lineID]

        # 4- updates nextLine and prevLines, insert frag in the editor
        if secondAddedLine != null
            lineNextStartLine                = currSel.startLine.lineNext
            currSel.startLine.lineNext       = secondAddedLine
            secondAddedLine.linePrev = currSel.startLine
            if lineNextStartLine == null
                @editorBody$[0].appendChild(frag)
            else
                domWalkContext.lastAddedLine.lineNext   = lineNextStartLine
                lineNextStartLine.linePrev = domWalkContext.lastAddedLine
                @editorBody$[0].insertBefore(frag, lineNextStartLine.line$[0])
        
        # 5- position carret


        console.log htmlStr


    _domWalk : (elemt, context) ->
        absDepth = context.absDepth
        prevHxLevel = context.prevHxLevel
        result = ""
        for child in elemt.childNodes
            if child.nodeType == Node.TEXT_NODE
                txt = child.textContent
                txtTrimmed = txt.trim()
                # In the dom, after each element, there is a TextNode 
                # with text = "\n      " (seen in ff and chrome)
                # That's why we trim strings and eleminate empty txtTrimmed. 
                # Rq : "\n  ".trim() => ''
                # TODO : do not trim (could remove legacy spaces) but
                # rather replace with a regex the terminal "\n[ ]*$"
                # TODO : is there a possibility to have 2 or more TextNode in
                # an element ? 
                # ex : <p><TextNode>content1</TextNode><TextNode>content2</TextNode></p>
                # if yes, we should consider concatenate those TextNodes : to be done
                if txtTrimmed != ""  
                    txtTrimmed = "<span>"+txtTrimmed+"</span>"
                    type = "tyty"
                    result += Array(absDepth+1).join('|  ')+"<span>"+txtTrimmed+"</span>"+" - [type:"+type+" - AbsDepth:"+absDepth+"]\n"
                    p = 
                        sourceLine         : context.lastAddedLine
                        fragment           : txtTrimmed
                        targetLineType     : "Tu"
                        targetLineDepthAbs : absDepth
                        targetLineDepthRel : absDepth
                    context.lastAddedLine = @_insertLineAfter(p)
            else
                switch child.nodeName
                    when 'UL', 'OL'
                        # works well, unactivated until to realy develop this feature
                        # for the moment all lines are inserted at the same absDepth
                        # result += @_domWalk(child,absDepth+1 )
                        context.absDepth = absDepth
                        result += @_domWalk(child,context )
                    when 'H1','H2','H3','H4','H5','H6'
                        if prevHxLevel == null
                            prevHxLevel = +child.nodeName[1]
                        newHxLevel = +child.nodeName[1]
                        deltaHxLevel = newHxLevel-prevHxLevel
                        if deltaHxLevel > 0
                            # works well, unactivated until to realy develop this feature
                            # for the moment all lines are inserted at the same absDepth
                            # context.absDepth = absDepth+1 
                            context.prevHxLevel = newHxLevel
                            result += @_domWalk(child, context)
                        else 
                            context.absDepth = absDepth+deltaHxLevel
                            context.prevHxLevel = newHxLevel
                            result += @_domWalk(child, context)
                    else
                        if child.nodeName == 'DIV' and child.id.substr(0,5)=='CNID_'
                            @_clipBoard_Insert_InternalLine(child, context)
                        else
                            result += @_domWalk(child, context)

        # position carret

        return result    
    ###*
     * Insert in the editor a line from a pasted line that comes from a copy a line in a 
     * cozy note editor
     * @param  {html element} elemt a div ex : <div id="CNID_7" class="Lu-3"> ... </div>
     * @return {line}        a ref to the line object
    ###
    _clipBoard_Insert_InternalLine : (elemt, context)->
        lineClass = elemt.className.split('-')
        lineDepthAbs = +lineClass[1]
        lineClass = lineClass[0]
        if !context.prevCNLineAbsDepth
            context.prevCNLineAbsDepth = lineDepthAbs
        deltaDepth = lineDepthAbs - context.prevCNLineAbsDepth
        if deltaDepth > 0
            # context.absDepth += 1
        else
            # context.absDepth += deltaDepth
        p = 
            sourceLine         : context.lastAddedLine
            innerHTML          : elemt.innerHTML
            targetLineType     : "Tu"
            targetLineDepthAbs : context.absDepth
            targetLineDepthRel : context.absDepth
        context.lastAddedLine = @_insertLineAfter(p)

        
   
    ### ------------------------------------------------------------------------
    #  MARKUP LANGUAGE CONVERTERS
    # _cozy2md (Read a string of editor html code format and turns it into a
    #           string in markdown format)
    # _md2cozy (Read a string of html code given by showdown and turns it into
    #           a string of editor html code)
    ###

    #
    #  WARNING: an odd bug occurs around the 19-th line in the example :
    #           ./templates/content-shortlines-marker
    #           (there are some empty lines around)
    # 
    # Read a string of editor html code format and turns it into a string in
    #  markdown format
    _cozy2md : (text) ->
        
        # Writes the string into a jQuery object
        htmlCode = $(document.createElement 'div').html text
        
        # The future converted line
        markCode = ''

        # current depth
        currDepth = 0
        
        # converts a fragment of a line
        converter = {
            'A': (obj) ->
                title = if obj.attr('title')? then obj.attr('title') else ""
                href  = if obj.attr('href')? then obj.attr('href') else ""
                return '[' + obj.html() + '](' + href + ' "' + title + '")'
                    
            'IMG': (obj) ->
                title = if obj.attr('title')? then obj.attr('title') else ""
                alt   = if obj.attr('alt')? then obj.attr('alt') else ""
                src   = if obj.attr('src')? then obj.attr('src') else ""
                return '![' + alt + '](' + src + ' "' + title + '")'
                
            'SPAN': (obj) ->
                return obj.text()
            }

        
        # markup symbols
        markup = {
            'Th' : (blanks, depth) ->
                # a title is a section rupture
                currDepth = depth
                dieses = ''
                i = 0
                while i < depth
                    dieses += '#'
                    i++
                return "\n" + dieses + ' '
            'Lh' : (blanks, depth) ->
                return "\n"
            'Tu' : (blanks, depth) ->
                return "\n" + blanks + "+   "
            'Lu' : (blanks, depth) ->
                return "\n" + blanks + "    "
            'To' : (blanks, depth) ->
                return "\n" + blanks + "1.   "
            'Lo' : (blanks, depth) ->
                return "\n" + blanks + "    "
            }

        # adds structure depending of the line's class
        classType = (className) ->
            tab   = className.split "-"
            type  = tab[0]               # type of class (Tu,Lu,Th,Lh,To,Lo)
            depth = parseInt(tab[1], 10) # depth (1,2,3...)
            blanks = ''
            i = 1
            while i < depth - currDepth
                blanks += '    '
                i++
            return markup[type](blanks, depth)
        
        # iterate on direct children
        children = htmlCode.children()
        for i in [0..children.length-1]
            
            # fetch the i-th line of the text
            lineCode = $ children.get i
            
            # indent and structure the line
            if lineCode.attr('class')?
                # console.log classType lineCode.attr 'class'
                markCode += classType lineCode.attr 'class'

            # completes the text depending of the line's content
            l = lineCode.children().length
            j = 0
            space = ' '
            while j < l
                lineElt = lineCode.children().get j
                if (j+2==l) then space='' #be sure not to insert spaces after BR
                if lineElt.nodeType == 1 && converter[lineElt.nodeName]?
                    markCode += converter[lineElt.nodeName]($ lineElt) + space
                else
                    markCode += $(lineElt).text() + space
                j++
                
            # adds a new line at the end
            markCode += "\n"
        
        return markCode


    # Read a string of html code given by showdown and turns it into a string
    # of editor html code
    _md2cozy: (text) ->
    
        conv = new Showdown.converter()
        text = conv.makeHtml text
       
        # Writes the string into a jQuery object
        htmlCode = $(document.createElement 'ul').html text

        # final string
        cozyCode = ''
        
        # current line
        id = 0

        # Returns the corresponding fragment of cozy Code
        cozyTurn = (type, depth, p) ->
            # p is a (jquery) object that looks like this :
            # <p> some text <a>some link</a> again <img>some img</img> poof </p>
            # OR like this:  <li> some text <a>some link</a> ...
            # We are treating a line again, thus id must be increased
            id++
            code = ''
            p.contents().each () ->
                name = @nodeName
                if name == "#text"
                    code += "<span>#{$(@).text()}</span>"
                else if @tagName?
                    $(@).wrap('<div></div>')
                    code += "#{$(@).parent().html()}"
                    $(@).unwrap()
            return "<div id=CNID_#{id} class=#{type}-#{depth}>" + code +
                "<br></div>"
                
        # current depth
        depth = 0
        
        # Read sections sequentially
        readHtml = (obj) ->
            tag = obj[0].tagName
            if tag[0] == "H"       # c'est un titre (h1...h6)
                depth = parseInt(tag[1],10)
                cozyCode += cozyTurn("Th", depth, obj)
            else if tag == "P"     # ligne de titre
                cozyCode += cozyTurn("Lh", depth, obj)
            else
                recRead(obj, "u")
                
        # Reads recursively through the lists
        recRead = (obj, status) ->
            tag = obj[0].tagName
            if tag == "UL"
                depth++
                obj.children().each () ->
                    recRead($(@), "u")
                depth--
            else if tag == "OL"
                depth++
                obj.children().each () ->
                    recRead($(@), "o")
                depth--
            else if tag == "LI" && obj.contents().get(0)?
                # cas du <li>Un seul titre sans lignes en-dessous</li>
                if obj.contents().get(0).nodeName == "#text"
                    obj = obj.clone().wrap('<p></p>').parent()
                for i in [0..obj.children().length-1]
                    child = $ obj.children().get i
                    if i == 0
                        cozyCode += cozyTurn("T#{status}", depth, child)
                    else
                        recRead(child, status)
            else if tag == "P"
                cozyCode += cozyTurn("L#{status}", depth, obj)

        htmlCode.children().each () ->
            readHtml $ @
        
        return cozyCode


    # CLEANED UP HTML PARSING
    # 
    # We suppose the html treated here has already been sanitized so the DOM
    #  structure is coherent and not twisted
    # 
    # _parseHtml:
    #  Parse an html string and return the matching html in the editor's format
    # We try to restitute the very structure the initial fragment :
    #   > indentation
    #   > lists
    #   > images, links, tables... and their specific attributes
    #   > text
    #   > textuals enhancements (bold, underlined, italic)
    #   > titles
    #   > line return
    # 
    # Ideas to do that :
    #  0- textContent is always kept
    #  1- A, IMG keep their specific attributes
    #  2- UL, OL become divs whose class is Tu/To. LI become Lu/Lo
    #  3- H[1-6] become divs whose class is Th. Depth is determined depending on
    #     where the element was pasted.
    #  4- U, B have the effect of adding to each elt they contain a class (bold
    #     and underlined class)
    #  5- BR delimit the different DIV that will be added
    #  6- relative indentation preserved with imbrication of paragraphs P
    #  7- any other elt is turned into a simple SPAN with a textContent
    #  8- IFRAME, FRAME, SCRIPT are ignored
    # _parseHtml : (htmlFrag) ->
        
        # result = ''

        # specific attributes of IMG and A are copied
        # copySpecificAttributes =
            # "IMG" : (elt) ->
                # attributes = ''
                # for attr in ["alt", "border", "height", "width", "ismap", "hspace", "vspace", "logdesc", "lowsrc", "src", "usemap"]
                    # if attr?
                        # attributes += " #{attr}=#{elt.getAttribute(attr)}"
                # return "<img #{attributes}>#{elt.textContent}</img>"
            # "A" : (elt) ->
                # attributes = ''
                # for attr in ["href", "hreflang", "target", "title"]
                    # if attr?
                        # attributes += " #{attr}=#{elt.getAttribute(attr)}"
                # return "<a #{attributes}>#{elt.textContent}</a>"
                

        # read recursively through the dom tree and turn the html fragment into
        # a correct bit of html for the editor with the same specific attributes
        
        # leafReader = (tree) ->
            # if the element is an A or IMG --> produce an editor A or IMG
            # if tree.nodeName == "A" || tree.nodeName == "IMG"
                # return copySpecificAttributes[tree.nodeName](tree)
            # if the element is a BR
            # else if tree.nodeName == "BR"
                # return "<br>"
            # if the element is B, U, I, EM then spread this highlightment
            # if the element is UL(OL) then start a Tu(To)
            # if the element is LI then continue the list (unless if it is the
            #    first child of a UL-OL)
            # else
            # else if tree.firstChild != null
                # sibling = tree.firstChild
                # while sibling != null
                   #  result += leafReader(sibling)
                    # sibling = sibling.nextSibling
            # if the element
                # src = "src=#{tree.getAttribute('src')}"
            
            # if the element has children
            # child = tree.firstChild
            # if child != null
            #     while child != null
                    # result += leafReader(child)
                    # child = child.nextSibling
            # else
                
                # return tree.innerHTML || tree.textContent

        # leafReader(htmlFrag)