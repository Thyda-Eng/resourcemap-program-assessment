module Collection::SettingConcern
  extend ActiveSupport::Concern

  def update_setting(collectionSetting)
    self.update_attributes({category: collectionSetting[:category], standard_id: collectionSetting[:standard_id],
      timeframe_ids: collectionSetting[:timeframe_ids]})
  end

end
