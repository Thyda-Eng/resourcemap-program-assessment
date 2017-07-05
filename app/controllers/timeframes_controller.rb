class TimeframesController < ApplicationController

  def create
    timeframe = Timeframe.new(params[:option])
    if timeframe.save
      render json: timeframe.as_json
    else
      render json: {status: 200, errors: timeframes.errors.full_messages}
    end

  end

  def update
    timeframe = Timeframe.find params[:id]
    timeframe.update_attributes(params[:option])
    render json: timeframe
  end

  def destroy
    timeframe = Timeframe.find params[:id]
    timeframe.destroy
    render json: timeframe
  end


end
