class CreateStandards < ActiveRecord::Migration
  def change
    create_table :standards do |t|
      t.string :label
      t.integer :ord

      t.timestamps
    end
  end
end
