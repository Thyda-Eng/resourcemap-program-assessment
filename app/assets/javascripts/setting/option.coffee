onSetting ->
  class @Option
    constructor: (data)->
      @id = data?.id
      @label = ko.observable(data?.label)
      @ord = ko.observable(data?.ord)
      @editing = ko.observable(false)
      @valid = ko.computed => $.trim(@label()).length > 0 && $.trim(@ord()).length > 0


    edit: =>
      console.log 'edit'
      @editing(true)
