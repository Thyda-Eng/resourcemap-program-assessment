class StandardsController < ApplicationController

  def create
    standard = Standard.new(params[:option])
    if standard.save
      render json: standard.as_json
    else
      render json: {status: 200, errors: standard.errors.full_messages}
    end

  end

  def update
    standard = Standard.find params[:id]
    standard.update_attributes(params[:option])
    render json: standard
  end

  def destroy
    standard = Standard.find params[:id]
    standard.destroy
    render json: standard
  end


end
