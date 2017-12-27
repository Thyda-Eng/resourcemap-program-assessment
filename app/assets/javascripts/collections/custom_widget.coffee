onCollections ->
  class @CustomWidget
    constructor: (field) ->
      @field = field
      @element = $('#wrapper-custom-widget-'+@field.code)

    bindField: ->
      if @element.length > 0
        if @element.attr("data-readonly") == 'readonly'
          @createReadOnlyElement()
        else
          @createEditableElement()
        ko.applyBindings(@field, @element.get(0) )

    createReadOnlyElement: ->
      if @field.kind == 'numeric' || @field.kind == 'custom_aggregator'|| @field.kind == 'text'
        node = """
              <span data-bind="text: value" id="custom-widget-#{@field.code}" class="custom"></span>
            """
      else if @field.kind == 'select_one'
        @field.value(parseInt(@field.value()))
        node = """
              <span data-bind="text: valueUI" id="custom-widget-#{@field.code}" class="custom"></span>
            """
      @element.append(node)


    createEditableElement: ->
      if @field.kind == 'numeric' || @field.kind == 'text'
        node = """
                 <input type="text" name="custom-widget-#{@field.code}"
                        data-bind="value: value, event: {keydown: keyPress}, css: {error: error}, attr: {title: name}" id="custom-widget-#{@field.code}"
                        class="custom key-map-integer" />
                 <span data-bind="text: errorMessage, validationPopover: errorMessage" style="display:none"></span>
               """
      else if @field.kind == 'select_one'
        options = "<option value=''>(no value)</option>"
        options = options + $.map(@field.options, (option, index) ->
                  "<option value=\"#{option['id']}\">#{option['label']}</option>"
                  )
        node = """
                <select  data-bind="value: value, css: {error: error}" id="custom-widget-#{@field.code}">
                  #{options}
                </select>
               """
      else if @field.kind == 'calculation' && @field.is_display_field()
        node = """
                <input type="text" id="custom-widget-#{@field.code}"
                  data-bind="value: value" readonly='readonly' class='custom' />
               """
      @element.append(node)
