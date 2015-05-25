# Include this module to get search methods that will modify
# a @search instance that must be a Tire::Search object.
#
# The class that includes this module must provide a collection
# method that returns the collection being searched.
#
# Before executing the search you must invoke apply_queries.
module SearchBase
  def use_codes_instead_of_es_codes
    @use_codes_instead_of_es_codes = true
    self
  end

  def id(id)
    @search.filter :term, id: id
    self
  end

  def name_start_with(name)
    @search.filter :prefix, name: name.downcase
  end

  def name(name)
    @search.filter :term, name_not_analyzed: name
  end

  def uuid(uuid)
    @search.filter :term, uuid: uuid
  end

  def eq(field, value)
    if value.blank?
      add_filter key: "field", value: field.es_code , type: :missing
      return self
    end

    validated_value = field.apply_format_query_validation(value, @use_codes_instead_of_es_codes)
    query_key = field.es_code

    if field.kind == 'yes_no'
      add_filter key: query_key, value: Field.yes?(value), type: :term
    elsif field.kind == 'date'
      date_field_range(query_key, validated_value)
    elsif field.kind == 'hierarchy' and value.is_a? Array
      add_filter key: query_key, value: validated_value, type: :terms
    elsif field.select_kind?
      add_filter key: query_key, value: validated_value, type: :term
    else
      add_filter key: query_key, value: value, type: :term
    end

    self
  end

  def under(field, value)
    if value.blank?
      add_filter key: "field", value: field.es_code, type: :missing
      return self
    end

    # TODO: Why is this double check necessary?
    value = field.descendants_of_in_hierarchy value, @use_codes_instead_of_es_codes
    validated_value = field.apply_format_query_validation(value, @use_codes_instead_of_es_codes)
    query_key = field.es_code
    add_filter key: query_key, value: validated_value, type: :terms
    self
  end

  def starts_with(field, value)
    validated_value = field.apply_format_query_validation(value, @use_codes_instead_of_es_codes)
    query_key = field.es_code
    add_filter key: query_key, value: validated_value, type: :prefix
    self
  end

  ['lt', 'lte', 'gt', 'gte'].each do |op|
    class_eval %Q(
      def #{op}(field, value)
        validated_value = field.apply_format_query_validation(value, @use_codes_instead_of_es_codes)
        add_filter key: field.es_code, value: {#{op}: validated_value}, type: :range
        self
      end
    )
  end

  def op(field, op, value)
    case op.to_s.downcase
    when '<', 'l' then lt(field, value)
    when '<=', 'lte' then lte(field, value)
    when '>', 'gt' then gt(field, value)
    when '>=', 'gte' then gte(field, value)
    when '=', '==', 'eq' then eq(field, value)
    when 'under' then under(field, value)
    else raise "Invalid operation: #{op}"
    end
    self
  end

  def where(properties = {})
    properties.each do |es_code, value|
      field = check_field_exists es_code
      
      if value.is_a? String
        case
        when value[0 .. 1] == '<=' then lte(field, value[2 .. -1].strip)
        when value[0] == '<' then lt(field, value[1 .. -1].strip)
        when value[0 .. 1] == '>=' then gte(field, value[2 .. -1].strip)
        when value[0] == '>' then gt(field, value[1 .. -1].strip)
        when value[0] == '=' then eq(field, value[1 .. -1].strip)
        when value[0 .. 1] == '~=' then starts_with(field, value[2 .. -1].strip)
        else eq(field, value)
        end
      elsif value.is_a? Hash
        value.each { |pair| op(field, pair[0], pair[1]) }
      else
        eq(field, value)
      end
    end
    self
  end

  def date_field_range(key, valid_value)
    date_from = valid_value[:date_from]
    date_to = valid_value[:date_to]

    add_filter key: key, value: {gte: date_from, lte: date_to}, type: :range
    self
  end

  def before(time)
    time = parse_time(time)
    @search.filter :range, updated_at: {lte: Site.format_date(time)}
    self
  end

  def after(time)
    time = parse_time(time)
    updated_since_query(time)
  end

  def updated_since(iso_string)
    time = Time.iso8601(iso_string)
    updated_since_query(time)
  end

  def updated_since_query(time)
    add_filter key: :updated_at, value: {gte: Site.format_date(time)}, type: :range
  end

  def alerted_search(v)
    @search.filter :term, alert: v
    self
  end

  def date_query(iso_string, field_name)
    # We use a 2 seconds range, not the exact date, because this would be very restrictive
    time = Time.iso8601(iso_string)
    time_upper_bound = time + 1.second
    time_lower_bound = time - 1.second
    @search.filter :range, field_name.to_sym => {gte: Site.format_date(time_lower_bound)}
    @search.filter :range, field_name.to_sym => {lte: Site.format_date(time_upper_bound)}
    self
  end

  def updated_at(iso_string)
    date_query(iso_string, 'updated_at')
  end

  def created_at(iso_string)
    date_query(iso_string, 'created_at')
  end

  def full_text_search(text)
    query = ElasticSearch::QueryHelper.full_text_search(text, @search, collection, fields)
    add_query query if query
    self
  end

  def box(west, south, east, north)
    @search.filter :geo_bounding_box, location: {
      top_left: {
        lat: north,
        lon: west
      },
      bottom_right: {
        lat: south,
        lon: east
      },
    }
    self
  end

  def radius(lat, lng, meters)
    meters = meters.to_f / 1000 unless meters.is_a?(String) && (meters.end_with?('km') || meters.end_with?('mi'))
    @search.filter :geo_distance,
      distance: meters,
      location: { lat: lat, lon: lng }
    self
  end

  def require_location
    @search.filter :exists, field: :location
    self
  end

  def location_missing
    add_filter key: :exists, value: {field: :location}, type: :not
  end

  def eq_hierarchy(field, value)
    if value.blank?
      @search.filter :missing, {field: field.es_code}
      return self
    end

    validated_value = field.apply_format_query_validation(value, @use_codes_instead_of_es_codes)
    query_key = field.es_code

    if field.kind == 'yes_no'
      @search.filter :term, query_key => Field.yes?(value)
    elsif field.kind == 'date'
      date_field_range(query_key, validated_value)
    elsif field.kind == 'hierarchy' and value.is_a? Array
      @search.filter :terms, query_key => validated_value
    elsif field.select_kind?
      @search.filter :term, query_key => validated_value
    else
      @search.filter :term, query_key => value
    end

    self
  end

  def hierarchy(es_code, value)
    field = check_field_exists es_code
    if value.present?
      eq_hierarchy field, value
    else
      @search.filter :not, {exists: {field: es_code}}
    end
  end

  def set_formula(formula)
    @formula = formula
  end

  def is_number(str)
    /^[0-9]+$/ === str
  end

  def is_code(str)
    /^[A-Za-z]+$/ === str
  end

  def tokenize
    @formula.split(" ") if @formula
  end

  def parse
    $tokens = tokenize
    $position = 0

    def peek
      if $tokens
        return $tokens[$position]
      end
    end

    def parsePrimaryExpr
      t = peek
      res = {}
      if t == "("
        $position += 1
        res = parseExpr
        $position += 1
      else
        $position += 1
        if t == "location_missing" 
          t = :exists
        elsif t == "update" 
          t = :updated_at
        end
        @filters.each do |f|
          if f[:key] == t || (f[:key] == "field" && f[:value] == t)
            res = {f[:type]=> {f[:key] => f[:value]}}
            break
          end
        end
      end
      return res
    end

    def parseExpr
      expr = parsePrimaryExpr
      t = peek
      while t == "and" || t == "or" do
        $position += 1
        nextExpr = parsePrimaryExpr
        expr = {t => [expr, nextExpr]}
        t = peek
      end
    
      return expr
    end

    parseExpr
  end

  def prepare_filter
    if @filters
      expr = parse
      @search.query { |q| q.all}
      @search.filter expr.keys[0] , expr.values[0]
    end
    self
  end

  def apply_queries 
    @search.query { |q|
      query = @queries.join " AND " if @queries
      case
      when @queries && @prefixes
        q.boolean do |bool|
          bool.must { |q| q.string query }
          apply_prefixes bool
        end
      when @queries && !@prefixes then q.string query
      when !@queries && @prefixes then apply_prefixes q
      else q.all
      end
    }
  end

  def select_fields(fields_array)
    @search.fields(fields_array)
    self
  end

  private

  def apply_prefixes to
    if to.is_a? Tire::Search::BooleanQuery
      @prefixes.each do |prefix|
        to.must { |q| q.prefix prefix[:key], prefix[:value] }
      end
    else
      if @prefixes.length == 1
        to.prefix @prefixes.first[:key], @prefixes.first[:value]
      else
        to.boolean { |bool| apply_prefixes bool }
      end
    end
  end

  def decode(code)
    return code unless @use_codes_instead_of_es_codes

    code = remove_at_from_code code
    fields.find { |x| x.code == code }.es_code
  end

  def remove_at_from_code(code)
    code.start_with?('@') ? code[1 .. -1] : code
  end

  def add_query(query)
    @queries ||= []
    @queries.push query
  end

  def add_filter(query)
    @filters ||= []
    @filters.push query
  end

  def parse_time(time)
    if time.is_a? String
      time = case time
      when /last(_|\s*)hour/i then Time.now - 1.hour
      when /last(_|\s*)day/i then Time.now - 1.day
      when /last(_|\s*)week/i then Time.now - 1.week
      when /last(_|\s*)month/i then Time.now - 1.month
      else Time.parse(time)
      end
    end
    time
  end

  def check_field_exists(code)
    if @use_codes_instead_of_es_codes
      code = remove_at_from_code code
      fields_with_code = fields.select{|f| f.code == code}
      raise "Unknown field: #{code}" unless fields_with_code.length > 0
      fields_with_code[0]
    else
      fields_with_es_code = fields.select{|f| f.es_code == code}
      raise "Unknown field: #{code}" unless fields_with_es_code.length > 0
      fields_with_es_code[0]
    end
  end

  def fields
    @_fields_ ||= collection.fields.all
  end
end
