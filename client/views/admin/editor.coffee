class @BlogEditor extends MediumEditor

  # FACTORY
  @make: (tpl) ->
    $editable = $ '.editable'

    if $editable.data('mediumEditor')
      return $editable.data('mediumEditor')

    # Set up the medium editor with image upload
    editor = new BlogEditor $editable[0],
      placeholder: ''
      firstHeader: 'h1'
      secondHeader: 'h2'
      buttonLabels: 'fontawesome'
      buttons:
        ['bold', 'italic', 'underline', 'anchor', 'pre', 'header1', 'header2', 'orderedlist', 'unorderedlist', 'quote', 'image']
      onShowToolbar: =>
        # Disable medium toolbar if we are in a code block
        if @inPreformatted()
          editor.toolbar.hideToolbar()


    tpl.$('.editable').mediumInsert
      editor: editor
      enabled: true
      addons:
        images:
          fileUploadOptions:
            submit: (e, data) ->
              self = tpl.$('.editable').data('plugin_mediumInsertImages')
              file = data.files[0]
              # Use CollectionFS + Amazon S3
              if Meteor.settings?.public?.blog?.useS3
                S3Files.insert file, (err, object) ->
                  Tracker.autorun (c) ->
                    theFile = S3Files.findOne({_id: object._id})
                    if theFile.isUploaded() and theFile.url?()
                      # insert-plugin assumes a server response, but we are
                      # cooler than that so pretend this came from a server
                      self.uploadDone e,
                        result:
                          files: [ url: theFile.url() ]
                        context: data.context
                      c.stop()
              # Use Local Filestore
              else
                id = FilesLocal.insert
                  _id: Random.id()
                  contentType: 'image/jpeg'
                # format data
                formdata = new FormData()
                formdata.append('file', file)
                $.ajax
                  type: "post"
                  url: Meteor.settings.public.contextPath + "/fs/#{id}"
                  xhr: ->
                    xhr = new XMLHttpRequest()
                    xhr.upload.onprogress = (data) ->
                    xhr
                  cache: false
                  contentType: false
                  processData: false
                  data: formdata
                  complete: (jqxhr) ->
                    self.uploadDone e,
                      result:
                        files: [ url: Meteor.settings.public.contextPath + "/fs/#{id}" ]
                      context: data.context

        #embeds: {}


    $editable.data 'mediumEditor', editor
    editor

  # INSTANCE METHODS

  constructor: ->
    @init.apply @, arguments

  # Return medium editor's contents
  contents: ->
    @serialize()['element-0'].value

  # Return medium editor's contents thru HTML beautifier
  pretty: ->
    html_beautify @contents(),
      preserve_newlines: false
      indent_size: 2
      wrap_line_length: 0

  # Highlight code blocks
  highlightSyntax: ->
    hljs.configure userBR: true

    br2nl = (i, html) ->
      html
        # medium-editor leaves <br>'s in <pre> tags, which screws up
        # highlight.js. Replace them with actual newlines.
        .replace(/<br>/g, "\n")
        # Strip out highlight.js tags so we don't create them multiple times
        .replace(/<[^>]+>/g, '')

    # Remove 'hljs' class so we don't create it multiple times
    $(@elements[0]).find('pre').removeClass('hljs').html(br2nl).each (i, block) ->
      hljs.highlightBlock block

  @inPreformatted: ->
    node = document.getSelection().anchorNode
    current = if node and node.nodeType == 3 then node.parentNode else node

    loop
      if current.nodeType == 1
        if current.tagName.toLowerCase() is 'pre'
          return true

        # do not traverse upwards past the nearest containing editor
        if current.getAttribute('data-medium-element')
          return false
      current = current.parentNode
      unless current
        break
    false
