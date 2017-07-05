class SettingController < ApplicationController

  def index
    setting = {categories: Collection::CATEGORIES, timeframes: Timeframe.all, standards: Standard.all}
    respond_to do |format|
      format.html
      format.json { render json: setting }
    end
  end

end
