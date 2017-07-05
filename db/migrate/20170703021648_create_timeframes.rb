class CreateTimeframes < ActiveRecord::Migration
  def change
    create_table :timeframes do |t|
      t.string :label
      t.integer :ord

      t.timestamps
    end
  end
end
