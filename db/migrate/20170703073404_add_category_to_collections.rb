class AddCategoryToCollections < ActiveRecord::Migration
  def change
    add_column :collections, :category, :string, default: 'NONE'
  end
end
