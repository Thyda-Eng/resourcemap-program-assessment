# == Schema Information
#
# Table name: fields
#
#  id                       :integer          not null, primary key
#  collection_id            :integer
#  layer_id                 :integer
#  name                     :string(255)
#  code                     :string(255)
#  kind                     :string(255)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  config                   :binary(214748364
#  ord                      :integer
#  metadata                 :text
#  is_mandatory             :boolean          default(FALSE)
#  is_enable_field_logic    :boolean          default(FALSE)
#  is_enable_range          :boolean          default(FALSE)
#  is_display_field         :boolean
#  custom_widgeted          :boolean          default(FALSE)
#  is_custom_aggregator     :boolean          default(FALSE)
#  is_criteria              :boolean          default(FALSE)
#  readonly_custom_widgeted :boolean          default(FALSE)
#

class Field < ActiveRecord::Base
  include Field::Base
  include Field::TireConcern
  include Field::ValidationConcern
  include Field::ShpConcern

  include HistoryConcern

  self.inheritance_column = :kind

  belongs_to :collection
  belongs_to :layer

  validates_presence_of :ord
  validates_inclusion_of :kind, :in => proc { kinds() }
  validates_presence_of :code
  validates_exclusion_of :code, :in => proc { reserved_codes() }
  validates_uniqueness_of :code, :scope => :collection_id
  validates_uniqueness_of :name, :scope => :collection_id

  serialize :config, MarshalZipSerializable
  serialize :metadata

  after_save :touch_collection_lifespan
  after_destroy :touch_collection_lifespan

  def self.reserved_codes
    ['lat', 'long', 'name', 'resmap-id', 'last updated']
  end

  before_save :set_collection_id_to_layer_id, :unless => :collection_id?
  def set_collection_id_to_layer_id
    self.collection_id = layer.collection_id if layer
  end

  before_save :save_config_as_hash_not_with_indifferent_access, :if => :config?
  def save_config_as_hash_not_with_indifferent_access
    self.config = config.to_hash

    self.config['options'].map!(&:to_hash) if self.config['options']
    sanitize_hierarchy_items self.config['hierarchy'] if self.config['hierarchy']
  end

  after_create :update_collection_mapping
  def update_collection_mapping
    collection.update_mapping
  end

  # inheritance_column added to json
  def serializable_hash(options = {})
    { "kind" => kind }.merge super
  end

  class << self
    def new_with_cast(*field_data, &b)
      hash = field_data.first
      kind = (field_data.first.is_a? Hash)? hash[:kind] || hash['kind'] || sti_name : sti_name
      klass = find_sti_class(kind)
      raise "Field is an abstract class and cannot be instanciated."  unless (klass < self || self == klass)
      hash.delete "kind" if hash
      hash.delete :kind if hash
      klass.new_without_cast(*field_data, &b)
    end
    alias_method_chain :new, :cast
  end

  def self.find_sti_class(kind)
    "Field::#{kind.classify}Field".constantize
  end

  def self.sti_name
    from_class_name_to_underscore(name)
  end

  def self.inherited(subclass)
    Layer.has_many "#{from_class_name_to_underscore(subclass.name)}_fields".to_sym, class_name: subclass.name
    Collection.has_many "#{from_class_name_to_underscore(subclass.name)}_fields".to_sym, class_name: subclass.name
    super
  end

  def self.from_class_name_to_underscore(name)
    underscore_kind = name.split('::').last.underscore
    match = underscore_kind.match(/(.*)_field/)
    if match
      match[1]
    else
      underscore_kind
    end
  end

  def assign_attributes(new_attributes, options = {})
    if (new_kind = (new_attributes["kind"] || new_attributes[:kind]))
      if new_kind == kind
        new_attributes.delete "kind"
        new_attributes.delete :kind
      else
        raise "Cannot change field's kind"
      end
    end
    super
  end

  def history_concern_foreign_key
    'field_id'
  end

  def default_value_for_create(collection)
    nil
  end

  def value_type_description
    "#{kind} values"
  end

  def value_hint
    nil
  end

  def error_description_for_invalid_values(exception)
    "are not valid for the type #{kind}"
  end

  # Enables caching options and other info for a read-only usage
  # of this field, so that validations and such can be performed faster.
  def cache_for_read
  end

  private

  def add_option_to_options(options, option)
    if option["parent_id"] and option["level"]
      options << { id: option['id'], name: option['name'], parent_id: option['parent_id'], level: option['level']}
    else
      options << { id: option['id'], name: option['name']}
    end
    if option['sub']
      option['sub'].each do |sub_option|
        add_option_to_options(options, sub_option)
      end
    end
  end

  def sanitize_hierarchy_items(items)
    items.map! &:to_hash
    items.each do |item|
      sanitize_hierarchy_items item['sub'] if item['sub']
    end
  end
end
