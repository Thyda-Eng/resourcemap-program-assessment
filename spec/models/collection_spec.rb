require 'spec_helper'

describe Collection do
  it { should validate_presence_of :name }
  it { should have_many :memberships }
  it { should have_many :users }
  it { should have_many :layers }
  it { should have_many :fields }
  it { should have_many :thresholds }

  let!(:user) { User.make }
  let!(:collection) { user.create_collection Collection.make_unsaved }
  let!(:layer) { collection.layers.make user: user, fields_attributes: [{kind: 'numeric', code: 'foo', name: 'Foo', ord: 1}] }
  let!(:field) { layer.fields.first }

  context "max value" do
    it "gets max value for property that exists" do
      collection.sites.make :properties => {field.es_code => 10}
      collection.sites.make :properties => {field.es_code => 20}, :lat => nil, :lng => nil
      collection.sites.make :properties => {field.es_code => 5}

      collection.max_value_of_property(field.es_code).should eq(20)
    end
  end

  describe "thresholds test" do
    let!(:properties) { { field.es_code => 9 } }
    let!(:site) { collection.sites.make}
    it "should return false when there is no threshold" do
      collection.thresholds_test(properties, site.id).should be_false
    end

    it "should return false when no threshold is hit" do
      collection.thresholds.make is_all_site: false, conditions: [ field: 1, op: :gt, value: 10 ]
      collection.thresholds_test(properties, site.id).should be_false
    end

    it "should return true when threshold 1 is hit" do
      collection.thresholds.make is_all_site: false, sites: [{"id" => site.id}], conditions: [ field: field.es_code, op: :lt, value: 10 ]
      collection.thresholds_test(properties, site.id).should be_true
    end

    it "should return true when threshold 2 is hit" do
      collection.thresholds.make sites: [{"id" => site.id}], conditions: [ field: field.es_code, op: :gt, value: 10 ]
      collection.thresholds.make sites: [{"id" => site.id}], conditions: [ field: field.es_code, op: :eq, value: 9 ]
      collection.thresholds_test(properties, site.id).should be_true
    end
  end

  describe "SMS query" do
    pending do
      it "should prepare response_sms" do
        option = {:field_code => "AB", :field_id => 2}
        result = [{"_source"=>{"id"=>1, "name"=>"Siem Reap Health Center", "properties"=>{"1"=>15, "2"=>40, "3"=>6}}}]
        collection.response_prepare(option[:field_code], option[:field_id], result).should eq("[\"#{option[:field_code]}\"] in #{[result[0]["_source"]["name"],40].join(", ")}")
      end
    end

    describe "Operator parser" do
      it "should return operator for search class" do
        collection.operator_parser(">").should eq("gt")
        collection.operator_parser("<").should eq("lt")
        collection.operator_parser("=>").should eq("gte")
        collection.operator_parser("=<").should eq("lte")
        collection.operator_parser(">=").should eq("gte")
        collection.operator_parser("<=").should eq("lte")
      end
    end
  end

  describe "History" do
    it "shold have user_snapshots througt snapshots" do
      snp_1 = collection.snapshots.create! date: Time.now, name: 'snp1'
      snp_2 = collection.snapshots.create! date: Time.now, name: 'snp2'

      snp_1.user_snapshots.create! user: User.make
      snp_2.user_snapshots.create! user: User.make

      collection.user_snapshots.count.should eq(2)
      collection.user_snapshots.first.snapshot.name.should eq('snp1')
      collection.user_snapshots.last.snapshot.name.should eq('snp2')
    end

    it "should obtain snapshot for user if user_snapshot exists" do
      user = User.make
      snp_1 = collection.snapshots.create! date: Time.now, name: 'snp1'
      snp_1.user_snapshots.create! user: user

      snp_2 = collection.snapshots.create! date: Time.now, name: 'snp2'
      snp_2.user_snapshots.create! user: User.make

      snapshot = collection.snapshot_for(user)
      snapshot.name.should eq('snp1')
    end

    it "should obtain nil snapshot_name for user if user_snapshot does not exists" do
      snp_1 = collection.snapshots.create! date: Time.now, name: 'snp1'
      snp_1.user_snapshots.create! user: User.make

      user = User.make
      snapshot = collection.snapshot_for(user)
      snapshot.should be_nil
    end


  end

  describe "plugins" do


    it "should set plugins by names" do
      collection.selected_plugins = ['plugin_1', 'plugin_2']
      collection.plugins.should eq({'plugin_1' => {}, 'plugin_2' => {}})
    end

    it "should skip blank plugin name when setting plugins" do
      collection.selected_plugins = ["", 'plugin_1', ""]
      collection.plugins.should eq({'plugin_1' => {}})
    end

    it "should iterate selected plugins" do
      p_class = Struct.new(:name)
      p1 = p_class.new 'plugin1'
      p2 = p_class.new 'plugin2'
      Plugin.stub(:all).and_return [p1, p2]

      collection.selected_plugins = ['plugin2']
      collection_plugins = []
      collection.each_plugin do |plugin|
        collection_plugins << plugin
      end
      collection_plugins.should eq([p2])
    end

  end

end
