class Api::CollectionSettingsController < ApplicationController

  def index
    collection = Collection.find(params[:id])
    render json: { category: collection.category, standard_id: collection.standard_id, timeframe_ids: collection.timeframe_ids }
  end
end
