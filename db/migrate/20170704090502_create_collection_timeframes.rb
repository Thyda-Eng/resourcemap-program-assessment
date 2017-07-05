class CreateCollectionTimeframes < ActiveRecord::Migration
  def change
    create_table :collection_timeframes do |t|
      t.integer :collection_id
      t.integer :timeframe_id

      t.timestamps
    end
  end
end
