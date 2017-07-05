class CollectionTimeframe < ActiveRecord::Base
  belongs_to :collection
  belongs_to :timeframe
end
