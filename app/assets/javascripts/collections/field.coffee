onCollections ->

  # A Layer field
  class @Field
    constructor: (data, layerId) ->
      @layer_id = layerId
      @esCode = "#{data.id}"
      @code = data.code
      @name = data.name
      @kind = data.kind
      @ord = data.ord
      @is_mandatory = ko.observable data?.is_mandatory ? false
      @is_display_field = ko.observable data?.is_display_field ? false
      @is_enable_field_logic = data.is_enable_field_logic
      @is_enable_custom_validation = ko.observable data?.is_enable_custom_validation ? false
      @custom_widgeted = data.custom_widgeted
      @readonly_custom_widgeted = data.readonly_custom_widgeted
      @invisible_calculation = ko.computed =>
                                if @kind == "calculation" && !@is_display_field()
                                  return "invisible-div"

      @photo = ''
      @preKeyCode = null
      @photoPath = '/photo_field/'
      @showInGroupBy = @kind in ['select_one', 'select_many', 'hierarchy']
      @writeable = @originalWriteable = data?.writeable
      @config = ko.observable data?.config

      @allowsDecimals = ko.observable data?.config?.allows_decimals == 'true'
      @configCustomValidations = ko.observable data?.config?.field_validations
      @originalIsMandatory = data.is_mandatory
      @value = ko.observable()
      @value.subscribe =>
        @valid()
        @disableDependentSkipLogicField()
        @performCalculation()


      @keyType = if @allowsDecimals() then 'decimal' else 'integer'

      # is more semantic
      @isForCustomWidget = ko.computed ->
        data.custom_widgeted

      @widgetContentViewAsInput = ko.computed =>
        if(@kind == "custom_widget" && data.config?.widget_content != undefined)
          @replaceCustomWidget data.config?.widget_content
        else
          ""

      @widgetContentViewAsSpan = ko.computed =>
        if(@kind == "custom_widget" && data.config?.widget_content != undefined)
          @replaceCustomWidget data.config?.widget_content, true
        else
          ""

      @hasValue = ko.computed =>
        if @kind == 'yes_no'
          true
        else if @kind == 'select_many'
          @value() && @value().length > 0
        else if @kind == 'numeric'
          @value() != '' && @value() != null && @value() != undefined
        else
          @value()

      @valueUI =  ko.computed
        read: => @valueUIFor(@value())
        write: (value) =>
          @value(@valueUIFrom(value))

      @field_logics = if data.config?.field_logics?
                        $.map data.config.field_logics, (x) => new FieldLogic x
                      else
                        []

      if @kind == 'numeric'
        @digitsPrecision = data?.config?.digits_precision
        @range = if data.config?.range?.minimum? || data.config?.range?.maximum?
                  data.config?.range


      if @kind in ['select_one', 'select_many']
        @options = if data.config?.options?
                    $.map data.config.options, (x) => new Option x
                  else
                    []
        @optionsIds = $.map @options, (x) => x.id

        # Add the 'no value' option
        @optionsIds.unshift('')
        @optionsUI = [new Option {id: '', label: window.t('javascripts.collections.fields.no_value') }].concat(@options)
        @optionsUIIds = $.map @optionsUI, (x) => x.id

        @hierarchy = @options

      if @kind == 'location'
        @locations = if data.config?.locations?
                      $.map data.config.locations, (x) => new Location x
                     else
                      []

        @resultLocations = ko.observableArray([])

        @maximumSearchLength = data.config?.maximumSearchLength

      if @kind == 'hierarchy'
        @hierarchy = data.config?.hierarchy

      @buildHierarchyItems() if @hierarchy?

      if @kind == 'select_many'
        @filter = ko.observable('') # The text for filtering options in a select_many
        @remainingOptions = ko.computed =>
          option.selected(false) for option in @options
          remaining = if @value()
            @options.filter((x) => @value()?.indexOf(x.id) == -1 && x.label.toLowerCase().indexOf(@filter().toLowerCase()) == 0)
          else
            @options.filter((x) => x.label.toLowerCase().indexOf(@filter().toLowerCase()) == 0)
          remaining[0].selected(true) if remaining.length > 0
          remaining
      else
        @filter = ->

      if @kind == 'calculation'
        @digitsPrecision = data?.config?.digits_precision
        @codeCalculation = data.config?.code_calculation
        @dependentFields = data.config?.dependent_fields

      @editing = ko.observable false
      @expanded = ko.observable false # For select_many
      @errorMessage = ko.observable()
      @error = ko.computed => !!@errorMessage()
      @skippedState = ko.observable(false)
      @errorClass = ko.computed => if @error() then 'error' else '' # For field number

      @is_blocked_by = ko.observableArray([])
      @blocked = ko.computed =>
        field_object = @get_dom_object(this)
        if @is_blocked_by() != undefined and @is_blocked_by().length> 0
          field_object.block({message: ""})
        else
          field_object.unblock()

    valid: =>
      @validateMandatory()
      @validateEmailFormat()
      @validateRangeAndDigitsPrecision()
      @validateCustomValidation()

    validateMandatory: =>
      if @is_mandatory()
        if !@value() || @value().length == 0
          @errorMessage('This field is required !')
        else
          @errorMessage('')

    validateEmailFormat: =>
      if @kind == 'email' && @value()
        re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        if(!re.test(@value().trim()))
          @errorMessage('Invalid field format')
        else
          @errorMessage('')

    replaceCustomWidget: (widgetContent, readonly) =>
      isReadonly = ''
      isReadonly = "data-readonly='readonly'" if readonly == true
      regExp = /(&nbsp;)|\{([^}]*)\}/g
      widget = widgetContent.replace(regExp, (match, space, token)->
        replace = space || token
        if replace == "&nbsp;"
          replaceBy = ''
        else
          replaceBy = """
                      <span id="wrapper-custom-widget-#{replace}" #{isReadonly}></span>
                      """
        return replaceBy
       )

    refresh_skip: =>
      if(@is_blocked_by().length > 0)
        tmp = @is_blocked_by()
        @is_blocked_by(tmp)

    bindWithCustomWidgetedField: =>
      if @kind == 'custom_widget'
        arr_field_wrapper = @widgetContentViewAsInput().match(/wrapper-custom-widget-[^"]+/g)
        for field_wrapper in arr_field_wrapper
          field_code = field_wrapper.split("wrapper-custom-widget-")[1]
          field = window.model.findFieldByCode(field_code)
          new CustomWidget(field).bindField()

    buildCompareFieldConfigOfCustomValidation: (fieldId, operator, compareField) =>
      compare = {
        field_id: fieldId,
        condition_type: operator
      }
      if ( compareField.config().compare_custom_validations )
        compareField.config().compare_custom_validations.push(compare)
      else
        compareField.config().compare_custom_validations = [compare]

    disableDependentSkipLogicField: =>
      if window.model.newOrEditSite()
        fieldSkipIds = @getRelatedSkipFieldIds()
        for field_id in fieldSkipIds
          field = window.model.newOrEditSite().findFieldByEsCode(field_id)
          skipFlag = false
          for field_logic in field.field_logics
            dependentField = window.model.newOrEditSite().findFieldByEsCode(field_logic.field_id)
            skipFlag = field_logic.isSkip(dependentField)
            if skipFlag == true
              @disableField(field, field_logic.field_id)
              break
          if(skipFlag == false)
            @enableField(field, dependentField.esCode)

    getRelatedSkipFieldIds: =>
      fieldSkipIds = []
      for field_logic in @relatedFieldLogics()
        if(fieldSkipIds.indexOf(field_logic.disable_field_id) == -1)
          fieldSkipIds.push field_logic.disable_field_id
      return fieldSkipIds

    getRelatedDisableField: (field_logic) =>
      @relatedFieldLogics().filter((x) =>
        "#{x.field_id}" == field_logic.field_id
      )


    getFieldFromAllFields: (field_id) =>
      $.map(window.model.newOrEditSite().fields(), (f) =>
        if f.esCode == field_id
          return f
      )

    #current field might be the dependentField of other field_logic
    #the disableField of that field_logic might have many related field_logics
    relatedFieldLogics: =>
      if model.allFieldLogics().length > 0
        return model.allFieldLogics().filter((x) => "#{x.field_id}" == @esCode)
      return []

    setFocusStyleByField: (field_id) =>
      field = window.model.newOrEditSite().findFieldByEsCode(field_id)
      if typeof field != 'undefined'
        @disableSkippedField(@esCode, field_id)
        if window.model.newOrEditSite().scrollable() == true
          @removeFocusStyle()
          if field.kind == "select_one"
            $('#select_one-input-'+field.code).focus()
          else if field.kind == "select_many"
            field.expanded(true)
            $('#select-many-input-'+field.code).focus()
          else if field.kind == "hierarchy"
            $('#'+field.esCode)[0].scrollIntoView(true)
            $('#'+field.esCode).focus()
          else if field.kind == "yes_no"
            $('#yes_no-input-'+field.code).focus()
          else if field.kind == "photo"
            $('#'+field.code).focus()
          else if field.kind == "date"
            $('#'+field.kind+'-input-'+field.esCode)[0].scrollIntoView(true)
            $('#'+field.kind+'-input-'+field.esCode).focus()
          else
            $('#'+field.kind+'-input-'+field.code).focus()
      else
        @enableSkippedField(@esCode, field_id)

    enableSkippedField: (field_id, by_field_id) =>
      flag = false
      $.map(window.model.editingSite().fields(), (f) =>
        if f.esCode == field_id
          flag = true
        if flag
          @enableField(f, by_field_id)
          return
      )

    disableSkippedField: (from_field_id, to_field_id) =>
      layers = window.model.currentCollection().layers()
      flag = false
      after_skip = false
      $.map(window.model.editingSite().fields(), (f) =>
        if f.esCode == from_field_id
          flag = true
          after_skip = true
          return true
        if f.esCode == to_field_id
          flag = false
        if flag
          @disableField f, from_field_id
        else
          if after_skip
            @enableField f
      )

    disableField: (field, by_field_id) =>
      field.is_mandatory(false)
      field.skippedState(true)
      field.is_blocked_by([])
      unless field.is_mandatory()
        if field.is_blocked_by() == undefined
          field.is_blocked_by([])
        index = field.is_blocked_by().indexOf(by_field_id)
        if(index < 0 )
          tmp = field.is_blocked_by()
          tmp.push(by_field_id) if by_field_id != undefined
        field.value(null)
        field.is_blocked_by(tmp)

    get_dom_object: (field) =>
      switch field.kind
        when 'select_one'
          field.value('')
          field_id = field.kind + "-input-" + field.code
          field_object = $("#" + field_id).parent()
        when 'select_many'
          if field.expanded()
            field_id = "select-many-input-" + field.code
            field_object = $("#" + field_id).parent().parent()
          else
            field.expanded(true)
            field_id = "select-many-input-" + field.code
            field_object = $("#" + field_id).parent().parent()
            field.expanded(false)

        when 'hierarchy'
          field_id = field.esCode
          field_object = $("#" + field_id).parent()
        when 'date'
          field_id = "date-input-" + field.esCode
          field_object = $("#" + field_id).parent()
        when 'photo'
          field_id = field.code
          field_object = $("#" + field_id).parent()
        else
          field_id = field.kind + "-input-" + field.code
          field_object = $("#" + field_id).parent()
      field_object

    enableField: (field, by_field_id) =>
      field.is_mandatory(field.originalIsMandatory) if field.skippedState() == false
      field.skippedState(false)
      field.is_blocked_by([]) if (field.is_blocked_by() != undefined and field.is_blocked_by().length > 0)

    setValueFromSite: (value) =>
      if @kind == 'date' && $.trim(value).length > 0
        # Value from server comes with utc time zone and creating a date here gives one
        # with the client's (browser) time zone, so we convert it back to utc
        date = new Date(value)
        date.setTime(date.getTime() + date.getTimezoneOffset() * 60000)
        value = @datePickerFormat(date)
      else if @kind == 'numeric' || @kind == 'calculation'
        value = @valueUIFor(value)

      value = '' if (value == null && value == '')

      @value(value)

    enableScrollFocusView: =>
      @valid()
      if @field_logics.length > 0
        if @value() == ""
          @enableSkippedField @esCode
        else
          window.model.newOrEditSite().scrollable(true)

    removeFocusStyle: =>
      $('div').removeClass('focus')
      $('input:not(#name)').removeClass('focus')
      $('select').removeClass('focus')
      $('select').blur()
      $('input').blur()

    codeForLink: (api = false) =>
      if api then @code else @esCode

    # The value of the UI.
    # If it's a select one or many, we need to get the label from the option code.
    valueUIFor: (value) =>
      if @kind == 'yes_no'
        if value then window.t('javascripts.collections.fields.yes') else window.t('javascripts.collections.fields.no')
      else if @kind == 'select_one'
        if value then @labelFor(value) else ''
      else if @kind == 'location'
        if value then @labelForLocation(value) else ''
      else if @kind == 'select_many'
        if value then $.map(value, (x) => @labelFor(x)).join(', ') else ''
      else if @kind == 'hierarchy'
        if value then @fieldHierarchyItemsMap[value] else ''
      else if @kind == 'site'
        name = window.model.currentCollection()?.findSiteNameById(value)
        if value && name then name else ''
      else if @kind == 'calculation' || @kind == 'numeric'
        if value != null && value != '' && value != 'NaN' && typeof value != 'undefined'
          if @digitsPrecision
            value = parseFloat(value)
            Number((value).toFixed(parseInt(@digitsPrecision)))
          else
            value
        else
          ''
      else
        if value != null && value != '' && typeof value != 'undefined' then value else ''

    valueUIFrom: (value) =>
      if @kind == 'site'
        # Return site_id or "" if the id for this name is not found (deleting the value or invalid value)
        window.model.currentCollection()?.findSiteIdByName(value) || ""
      else
        value

    datePickerFormat: (date) =>
      month = date.getMonth() + 1
      date.getDate() + '/' + month + '/' + date.getFullYear()

    buildHierarchyItems: =>
      @fieldHierarchyItemsMap = {}
      @fieldHierarchyItems = ko.observableArray $.map(@hierarchy, (x) => new FieldHierarchyItem(@, x))
      @fieldHierarchyItems.unshift new FieldHierarchyItem(@, {id: '', name: window.t('javascripts.collections.fields.no_value')})

    edit: =>
      @editing(true)
      if !window.model.currentCollection()?.currentSnapshot
        @originalValue = @value()

        # For select many, if it's an array we need to duplicate it
        if @kind == 'select_many' && typeof(@) == 'object'
          @originalValue = @originalValue.slice(0)

        @editing(true)
        optionsDatePicker = {}
        optionsDatePicker.onSelect = (dateText) =>
          @valueUI(dateText)
          @save()
        optionsDatePicker.onClose = () =>
          @save()
        window.model.initDatePicker(optionsDatePicker)
        window.model.initAutocomplete()
        window.model.initControlKey()


    validateRangeAndDigitsPrecision: =>
      @validateRange()
      @validateDigitsPrecision()

    validateDigitsPrecision: =>
      if @digitsPrecision and @value() != ""
        value = parseInt(@value() * Math.pow(10, parseInt(@digitsPrecision))) / Math.pow(10, parseInt(@digitsPrecision))
        if value then @value(value) else @value('')

    validateRange: =>
      if @range and @value()
        if @range.minimum && @range.maximum
          if parseFloat(@value()) >= parseFloat(@range.minimum) && parseFloat(@value()) <= parseFloat(@range.maximum)
            @errorMessage('')
          else
            @errorMessage('Invalid value, value must be in the range of ('+@range.minimum+'-'+@range.maximum+")")
        else
          if @range.maximum
            if parseFloat(@value()) <= parseFloat(@range.maximum)
              @errorMessage('')
            else
              @errorMessage('Invalid value, value must be less than or equal '+@range.maximum)
            return

          if @range.minimum
            if parseFloat(@value()) >= parseFloat(@range.minimum)
              @errorMessage('')
            else
              @errorMessage('Invalid value, value must be greater than or equal '+@range.minimum)
            return

    validateCustomValidation: =>
      if window.model.editingSite()
        if @is_enable_custom_validation()
          $.map(@configCustomValidations(), (f) =>
            field = window.model.editingSite().findFieldByEsCode(f.field_id[0])
            compareValue = field.value()
            if(!compareValue)
              compareValue = 0

            @generateErrorMessage(f, @, compareValue, field.name)
          )

        if @config().compare_custom_validations
          $.map(@config().compare_custom_validations, (v) =>
            field = window.model.editingSite().findFieldByEsCode(v.field_id)

            compareValue = @value()
            if(!compareValue)
              compareValue = 0

            @generateErrorMessage(v, field, compareValue, @name)
          )

    generateErrorMessage: (fieldConfig, validateField, compareValue, fieldName)=>
      compareValue = parseFloat(compareValue)
      fieldValue = parseFloat(validateField.value())
      if fieldConfig.condition_type == '='
        if fieldValue != compareValue
          validateField.errorMessage('Invalid value, value must be equal to field '+ fieldName)
        else
          validateField.errorMessage('')
      else if fieldConfig.condition_type == '<'
        if fieldValue >= compareValue
          validateField.errorMessage('Invalid value, value must be less than field '+ fieldName)
        else
          validateField.errorMessage('')
      else if fieldConfig.condition_type == '>'
        if fieldValue <= compareValue
          validateField.errorMessage('Invalid value, value must be greater than field '+ fieldName)
        else
          validateField.errorMessage('')
      else if fieldConfig.condition_type == '>='
        if fieldValue < compareValue
          validateField.errorMessage('Invalid value, value must be greater than and equal to field '+ fieldName)
        else
          validateField.errorMessage('')
      else if fieldConfig.condition_type == '<='
        if fieldValue > compareValue
          validateField.errorMessage('Invalid value, value must be less than and equal to field '+ fieldName)
        else
          validateField.errorMessage('')


    validate_integer_only: (keyCode) =>
      value = $('#'+@kind+'-input-'+@code).val()
      if value == null || value == ""
        if(keyCode == 189 || keyCode == 173) && (@preKeyCode != 189 || @preKeyCode == null || @preKeyCode == 173) #allow '-' for both chrome & firefox
          @preKeyCode = keyCode
          return true
      else
        if(keyCode == 189 || keyCode == 173) && value.charAt(0) != '-'
          @preKeyCode = keyCode
          return true
      if keyCode > 31 && (keyCode < 48 || keyCode > 57) && (keyCode != 8 && keyCode != 46) && keyCode != 37 && keyCode != 39  #allow right and left arrow key
        return false
      else
        @preKeyCode = keyCode
        return true

    validate_decimal_key: (keyCode) =>
      value = $('#'+@kind+'-input-'+@code).val()
      dotcontains = value.indexOf(".") != -1
      if (dotcontains)
        if (keyCode == 190)
          return false

      if (keyCode == 190)
        return true

      if (keyCode > 31 && (keyCode < 48 || keyCode > 57))
        return false
      return true

    validate_number_key: (keyCode) =>
      if keyCode > 31 && (keyCode < 48 || keyCode > 57)
        return false
      return true

    keyPress: (field, event) =>
      switch event.keyCode
        when 13 then @save()
        when 27 then @exit()
        else
          if field.kind == "numeric"
            if field.allowsDecimals()
              return @validate_decimal_key(event.keyCode)
            else
              return @validate_number_key(event.keyCode)
          return true

    exit: =>
      @value(@originalValue)
      @editing(false)
      @filter('')
      delete @originalValue

    save: =>
      window.model.editingSite().updateProperty(@esCode, @value())
      if !@error()
        @editing(false)
        @filter('')
        delete @originalValue

    closeDatePickerAndSave: =>
      if $('#ui-datepicker-div:visible').length == 0
        @save()

    selectOption: (option) =>
      @value([]) unless @value()
      @value().push(option.id)
      @value.valueHasMutated()
      @filter('')

    removeOption: (optionId) =>
      @value([]) unless @value()
      @value(arrayDiff(@value(), [optionId]))
      @value.valueHasMutated()

    expand: =>
      @expanded(true)
      @valid()

    filterKeyDown: (model, event) =>
      switch event.keyCode
        when 13 # Enter
          for option, i in @remainingOptions()
            if option.selected()
              @selectOption(option)
              break
          false
        when 38 # Up
          for option, i in @remainingOptions()
            if option.selected() && i > 0
              option.selected(false)
              @remainingOptions()[i - 1].selected(true)
              break
          false
        when 40 # Down
          for option, i in @remainingOptions()
            if option.selected() && i != @remainingOptions().length - 1
              option.selected(false)
              @remainingOptions()[i + 1].selected(true)
              break
          false
        else
          true

    labelFor: (id) =>
      for option in @optionsUI
        if option.id == id
          return option.label
      null

    labelForLocation: (code) =>
      for option in @resultLocations()
        if option.code == code
          return option.name
      ''

    # In the table view, use a fixed size width for each property column,
    # which depends on the length of the name.
    suggestedWidth: =>
      if @name.length < 10
        '100px'
      else
        "#{20 + @name.length * 8}px"

    isPluginKind: => -1 isnt PLUGIN_FIELDS.indexOf @kind

    exitEditing: ->
      if @kind == 'location'
        @resultLocations(@locations)

      @editing(false)
      @writeable = @originalWriteable

    fileSelected: (data, event) =>
      fileUploads = $("#" + data.code)[0].files

      if fileUploads.length > 0

        photoExt = fileUploads[0].name.split('.').pop()

        value = (new Date()).getTime() + "." + photoExt

        @value(value)

        reader = new FileReader()
        reader.onload = (event) =>
          @photo = event.target.result.split(',')[1]
          $("#imgUpload-" + @code).attr('src',event.target.result)
          $("#divUpload-" + @code).show()

        reader.readAsDataURL(fileUploads[0])
      else
        @photo = ''
        @value('')

      @valid()

    removeImage: =>
      @photo = ''
      @value('')
      $("#" + @code).attr("value",'')
      $("#divUpload-" + @code).hide()
      @valid()

    inputable: =>
      if (@kind == 'custom_widget' && @readonly_custom_widgeted == true) || @isForCustomWidget() || @kind == 'custom_aggregator'
        false
      else
        true

    visible: =>
      if (@kind != "calculation" || (@kind == "calculation" && @is_display_field())) && !@isForCustomWidget()
        true
      else
        false
    init: =>
      if @kind == 'date'
        window.model.initDatePicker()
      if window.model.newOrEditSite() && @kind == 'numeric' && @is_enable_custom_validation
        if @configCustomValidations()
          $.map(@configCustomValidations(), (c) =>
            compareField = window.model.newOrEditSite().findFieldByEsCode(c.field_id[0])
            @buildCompareFieldConfigOfCustomValidation(@esCode, c.condition_type, compareField)
          )

    performCalculation: =>
      $ele = new FieldView(@).domObject()
      calculationIds = $ele.attr('data-calculation-ids')?.split(",") ? []
      for calculationId in calculationIds
        if(calculationIds)
          window.model.newOrEditSite().updateField(calculationId)
