class AddStandardToCollections < ActiveRecord::Migration
  def change
    add_column :collections, :standard_id, :integer
  end
end
