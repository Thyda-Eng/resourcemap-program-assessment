module Field::FredApiConcern
  extend ActiveSupport::Concern

  # metadata: {"0"=>{"key"=>"context", "value"=>"MOH"}, "1"=>{"key"=>"agency", "value"=>"DHIS"}}

  def identifier?
    kind == 'identifier'
  end

  def context
    config['context']
  end

  def agency
    config['agency']
  end

  def fred_api_value(value)
    if date?
      # Values are stored in ISO 8601 format.
      value
    else
      api_value(value)
    end
  end
end
