require "./beerxml.rb"
include BeerXML


Shoes.app :height => 300, :width => 500, :title => "BrewTroller BeerXML Parser" do
	background 'beer-texture.jpg'
	@data = stack


	stack do
		flow :top => 150 do
			stack :width => '25%'
		
				@load = button "Load BeerXML", :width => '250' do
					file = ask_open_file
					BeerXML.parse_mash(file)
					@data.append do
						caption BeerXML.get_names, :align=> 'center'
						flow do
							stack :width => '33%' do caption "Mash Step ", :align=> 'center' end
							stack :width => '33%' do caption "Temperature ", :align=> 'center' end
							stack :width => '33%' do caption "Time", :align=> 'center' end
						end
			
						for i in 0..BeerXML.get_mash_temps.size-1
							flow do
								stack :width => '33%' do para i+1, :align=> 'center'
								end
								stack :width => '33%' do para BeerXML.get_mash_temps[i], :align=> 'center'
								end
								stack :width => '33%' do para BeerXML.get_mash_times[i], :align=> 'center'
								end
							end
						end
					
						stack do 
							style(:margin_left => '25%')
							flow do
								caption "Sparge Temperature: "
								para BeerXML.get_sparge_temp
							end
						end	
			
						flow do
							stack :width => '25%' do end
							stack :width => '50%' do 
								button "Download to Brewtroller", :width => '250' do
								end
							end
							stack :width => '25%' do end
						end			
					
					end
					@load.hide
				end
			end		
	end
end
	
