class CollectionSettingsController < ApplicationController

  def create
    collection = Collection.find(params[:id])
    collection.update_setting({category: params["category"], standard_id: params["standard_id"], timeframe_ids: params["timeframe_ids"]})
    render json: collection
  end

end
