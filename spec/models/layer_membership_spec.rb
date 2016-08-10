require 'spec_helper'

describe LayerMembership, :type => :model do
  describe 'telemetry' do
    let!(:user) { User.make }
    let!(:collection) { Collection.make }
    let!(:layer) { Layer.make collection: collection }
    let!(:membership) { Membership.make collection: collection, user: user }

    it 'should touch collection lifespan on create' do
      layer_membership = LayerMembership.make_unsaved collection: collection, user: user

      Telemetry::Lifespan.should_receive(:touch_collection).with(collection)

      layer_membership.save
    end

    it 'should touch collection lifespan on update' do
      layer_membership = LayerMembership.make collection: collection, user: user
      layer_membership.touch

      Telemetry::Lifespan.should_receive(:touch_collection).with(collection)

      layer_membership.save
    end

    it 'should touch collection lifespan on destroy' do
      layer_membership = LayerMembership.make collection: collection, user: user

      Telemetry::Lifespan.should_receive(:touch_collection).with(collection)

      layer_membership.destroy
    end

    it 'should touch user lifespan on create' do
      layer_membership = LayerMembership.make_unsaved collection: collection, user: user

      Telemetry::Lifespan.should_receive(:touch_user).with(user).at_least(:once)

      layer_membership.save
    end

    it 'should touch user lifespan on update' do
      layer_membership = LayerMembership.make collection: collection, user: user
      layer_membership.touch

      Telemetry::Lifespan.should_receive(:touch_user).with(user).at_least(:once)

      layer_membership.save
    end

    it 'should touch user lifespan on destroy' do
      layer_membership = LayerMembership.make collection: collection, user: user

      Telemetry::Lifespan.should_receive(:touch_user).with(user).at_least(:once)

      layer_membership.destroy
    end
  end
end
