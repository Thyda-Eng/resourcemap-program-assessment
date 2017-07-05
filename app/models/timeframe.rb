class Timeframe < ActiveRecord::Base
  has_many :collection_timeframes, :dependent => :destroy
  has_many :collections, through: :collection_timeframes
end
