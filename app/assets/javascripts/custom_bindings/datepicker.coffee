ko.bindingHandlers.datePicker =
  init: (element, valueAccessor) ->
    value = valueAccessor()

    $(element).val ko.utils.unwrapObservable value
    unless $(element).is '[readonly]'
      $(element).datepicker
        dateFormat: 'dd/mm/yy',
        yearRange: "-100:+5",
        changeMonth: true,
        changeYear: true
        onSelect: (selectedDate) ->
          value selectedDate
          $(@).datepicker 'hide'
