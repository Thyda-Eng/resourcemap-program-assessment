# == Schema Information
#
# Table name: layer_memberships
#
#  id            :integer          not null, primary key
#  collection_id :integer
#  user_id       :integer
#  layer_id      :integer
#  read          :boolean          default(FALSE)
#  write         :boolean          default(FALSE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class LayerMembership < ActiveRecord::Base
  belongs_to :collection
  belongs_to :user

  after_save :touch_collection_lifespan
  after_destroy :touch_collection_lifespan
  after_save :touch_user_lifespan
  after_destroy :touch_user_lifespan

  def self.filter_layer_membership current_user , collection_id
    builder = LayerMembership.where(
      :collection_id => collection_id, :user_id => current_user.id)
  end

end
