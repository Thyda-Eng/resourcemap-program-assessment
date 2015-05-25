onQueries ->
  class @Query
    constructor: (data) ->
      @id = ko.observable data?.id
      @name = ko.observable data?.name
      @formula = ko.observable data?.formula

      @conditions = if data?.conditions
                      ko.observableArray $.map(data.conditions, (x) => new Condition(x))
                    else
                      ko.observableArray()

      @nameError = ko.computed => if @hasName()  then null else "the query's name is missing"
      @queryError = ko.computed => if @conditions().length > 0  then null else "the query must have at least one condition refined"
      @formalaError = ko.computed => @hasFormulaError() || @LogicalOperatorError()
      @error = ko.computed => @nameError() || @queryError() || @formalaError()
      @valid = ko.computed => !@error()
      @isEditing = ko.observable(false)
      @isRefineQuery = ko.observable(false)

    hasName: => $.trim(@name()).length > 0

    hasFormula: => $.trim(@formula()).length > 0

    hasFormulaError: => if @hasFormula() then null else "the formula is missing"

    LogicalOperatorError: => if @isLogicalOperatorExpr().status then null else "the formula #{@isLogicalOperatorExpr().msg}"
    
    addCondition: =>
      @conditions.push(new Condition)

    removeCondition: (condition) =>
      @conditions.remove(condition)

    toJSON: =>
      id: @id()
      name: @name()
      formula: @formula()
      conditions: $.map(@conditions(), (x) -> x.toJSON())

    tokenize: =>
      results = []
      tokenRegExp = /\s*([A-Za-z]+|[0-9]+|\S)\s*/g
      formula = @formula()
      formula = formula.toLowerCase()
      m = undefined
      while (m = tokenRegExp.exec(formula)) != null
        results.push m[1]
      results

    condition_ids: =>
      ids = []
      for condition in @conditions()
        ids.push(parseInt(condition.id()))
      ids

    isLogicalOperatorExpr: =>
      tokens = @tokenize(@formula())
      position = 0
      ids = @condition_ids()

      peek = ->
        tokens[position]

      isValidNumber = (t)->
        if t != undefined && t.match(/^[0-9]+$/) != null
          ids.indexOf(parseInt(t)) > -1 

      isPrimaryExpr = ->
        t = peek()
        if isValidNumber(t)
          position++
          return {status: true, msg: "number"}
        else if t == '('
          position++
          expr = isExpr()
          if peek() != ')'
            expr = {status: false, msg: "expected )"}
          else 
            position++
          return expr
        else
          return {status: false, msg:"expected a number, or parentheses"}

      isExpr = ->
        expr = isPrimaryExpr()
        t = peek()
        while t == "and" || t == "or"
          position++
          nextExpr = isPrimaryExpr()
          if !expr.status || !nextExpr.status
            expr = {status : false, msg: "expected number before or after \'"+ t + "\'"}
            break
          expr = {status: true, msg: ""}
          t = peek()
        expr

      result = isExpr()

      if position != tokens.length
        result = {status: false, msg: "has unexpected \'" + peek() + "\'"}

      result

















