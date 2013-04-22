require 'spec_helper' 

describe "create_site" do 
 
  it "creates a site", js:true do
    @user = User.make(:email => 'user@manas.com.ar', :password => '1234567', :phone_number => '855123456789')
    @collection = create_collection_for(@user) 
    login_as (@user)
    visit collections_path
    sleep 2
    page.find(:xpath, '//div[@id="collections-main"]/div[1]/div[2]/table/tbody/tr[1]/td/button').click
    click_button "Create Site"
  	fill_in "name", :with => "New site"
  	fill_in "locationText", :with => '-34.682982, -58.437048'
  	click_button "Done"
  	sleep 1
  	page.save_screenshot "Create Site.png"
  	page.should have_content("Site 'New site' successfully created")
  end
end