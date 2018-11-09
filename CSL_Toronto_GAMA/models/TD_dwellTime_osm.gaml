/**
* Name: TD_dewlltimeOSM
* Author: farzin
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model TD_dwellTimeOSM

/* Insert your model definition here */

global {
	
	// not sure how it works yet. But I think I can import an OSM map, parse it and take the banks and coffee shops out of it.

	//map filtering <- map(["amenity"::["bank", "ATM","cafe"]]);
	
	// OSM file to load

	//file<geometry> osmfile <-  file<geometry>(osm_file("../includes/rouen.gz", filtering))  ;
	//geometry shape <- envelope(osmfile);	

	// Then in init function I can do something like this. I still need to know how to get the name of amenity.
	/*
		loop geom over: osmfile {
			if (shape covers geom) {
				string place_str <- string(geom get("amenity"));
				write place_str;
				if (length(geom.points) = 1 and ( place_str = "bank" or place_str = "cafe")) {
					create road with:[shape::geom, type::place_str]{
						nodes_map[location] <- self;
					}
					
				}
				if (length(geom.points) != 1 and (place_str = "bank" or place_str = "bank")){
					create road with:[shape::geom, type::place_str]{
						nodes_map[location] <- self;
					}					
				}
	*/



	shape_file shape_city <- shape_file("../includes/Buildings_TO_WGS84.shp");//shape_file("../includes/Route_Regional_Road.shp");//shape_file("../includes/2018_Vacant_Lands_with_PropertyPINS.shp");//
    geometry shape <- envelope(shape_city);

    list<string> userDate <- [];
    list<string> userTime <- [];
    list<string> user_Ids <- [];
    string userId;

    string DateTime <- "";
    list<point> user <- [];
    list<point> user_td <- [];

    int nb_people;
    int nb_bmo_people;
	int numberOfPeopleInBranches;

    	map<string, unknown> matrixData;
    	
	int hour;
	string filename;
	list<people> tempPeople;
	
	int day <- 0 parameter: "day";
	string region <- "" parameter:"region name:" category:"region";
	string output_file <- "DowntownToronto_201808_OSM" parameter:"input file" category:"input/output";
	string output_directory <- "../results/osm/yorkregion/" parameter:"output" category:"input/output"; 
	point bounding_box1 <- {0,0} parameter:"point 1" category: "Boundinx Box (lng , lat)" ;
	point bounding_box2 <- {0,0} parameter:"point 2" category: "Boundinx Box (lng , lat)" ;

	// I need to think about this to see how to eliminate hard coding static agents like banks or amenities.
	string td_file_name <- "../includes/TDlocationBased/tdDowntownToronto_locationBased_OSM_main.json" ;
	string bmo_file_name <- "../includes/TDlocationBased/bmoDowntownToronto_locationBased_OSM_main.json" ;
	string cibc_file_name <- "../includes/TDlocationBased/cibcDowntownToronto_locationBased_OSM_main.json" ;
	string ths_file_name <- "../includes/TDlocationBased/thsDowntownToronto_locationBased_OSM_main.json"; 

	// These fields are common between static agents like banks and amenities.
	map<string, unknown> cityMatrixData;
	list<map<string, unknown>> cityMatrixCell;
	list<float> density_array;
	list<float> current_density_array;	
	float lng;
	float lat;		
	point lower_left;
	point upper_right;
	list<point> polygonpoints <- [];	

	init {
			nb_people <- 0;
			hour <- 0;
			//  It would be great if we could pass the  species to an action to create the agents for us.
		  	do createTDs;
		  	do createBMO;
		  	do createCIBC;
		  	do createTimHortons;
		  	
		  	//day <- 1;		  	
			filename <- output_file + day + ".csv";// "RichmondHill_201808" + day + ".csv";// "Mississauga_201808" + day + ".csv";
		  	//do createpeople(0);
	  	
	}
	reflex name:start when:cycle=0{
		write "cycle 0";
		do createpeople(hour);
	}
			
	reflex name:repeat when: (cycle!= 0 and cycle mod 180 = 0){
		write "number of people= " + length(people);
		hour <- hour + 1;
		write "hour= " + hour;
		if hour > 23 {
			do pause;
		}
		else{
			do outputResults();
			do createpeople(hour);
		}
	}


	action outputResults{
			ask people{
				// Consider only the people spending time more than two minutes in a location.
				if self.dwell_time > 240{
					switch self.bank{
						match "TD"{
							save [id,userid,inbranch_location.x ,inbranch_location.y,user_date[length(user_date)-idx] + "-" + user_time[length(user_time)-idx],bankAddress,initLocation.x,initLocation.y,dwell_time] to: output_directory + "td/"+filename type:"csv" rewrite:false;
						}
						match "BMO"{
							
							save [id,userid,inbranch_location.x,inbranch_location.y,user_date[length(user_date)-idx] + "-" + user_time[length(user_time)-idx],bankAddress,initLocation.x,initLocation.y,dwell_time] to: output_directory + "bmo/"+filename type:"csv" rewrite:false;						
						}
						match "CIBC"{
							
							save [id,userid,inbranch_location.x,inbranch_location.y,user_date[length(user_date)-idx] + "-" + user_time[length(user_time)-idx],bankAddress,initLocation.x,initLocation.y,dwell_time] to: output_directory + "cibc/"+filename type:"csv" rewrite:false;						
						}
						match "THS"{
							
							save [id,userid,inbranch_location.x,inbranch_location.y,user_date[length(user_date)-idx] + "-" + user_time[length(user_time)-idx],bankAddress,initLocation.x,initLocation.y,dwell_time] to: output_directory + "ths/"+filename type:"csv" rewrite:false;						
						}
					}
					do die;
				}
			}			
		
	}


	action createpeople(int hr){
   		list<people> pep;
		write "reading csv file, " + day + " - " + hr;

		string h <- hr < 10 ? "0" + hr : hr;
		string d <- day < 10 ? "0" + day : day; 
		string fromAWStd_gama <-  "../files/2018/08/"+ d  + "/" + h + ".csv";//"http://localhost:8080/getCSVData/" + day + "/" + hr;//
		write fromAWStd_gama;
 		float plng <- 0.0;
		float plat <- 0.0;
		// Read location data from AWS cloud( to make it faster to run the model I feed the data locally for now)
		csv_file my_csv <- csv_file(fromAWStd_gama,",");
		matrix location_data <- matrix(my_csv);
		userId <- location_data[0,1];

		// Loop through the location data and group them based on userid.  Each user (people agent) has an array of locations which we use to check if the agent is inside an amenity or not.			
		loop r from: 1 to: location_data.rows -1{
				plng <- float(location_data[4,r]);
				plat <- float(location_data[3,r]);
				if (userId != location_data[0,r]){	
						if(!empty(user)){ 	
							create people{
								userid <- userId; 
								user_date <- userDate;
								user_time <- userTime;
								try{
									location <- user[0];
									initLocation <- user[0];
									agentMovementList <- user;
									user_TD_location <- user_td;
								}
								catch{
									write "catch, length user= " + length(user);
								}
							}
						}
						userId <- location_data[0,r];
						user <- [];
						userDate <- [];
						userTime <- [];
						user_td <- [];

						// Only create the agents which are inside a specific boundary (like downtown Toronto or Richmond Hill or .....) 
						if ( point(to_GAMA_CRS({plng, plat}, "EPSG:4326")) overlaps rectangle(point(to_GAMA_CRS({-79.435067,43.644925}, "EPSG:4326")), point(to_GAMA_CRS({-79.359908,43.669973}, "EPSG:4326")))){//(lng between (-79.405138,-79.370119) and lat between (43.644856,43.659994)){
							user <+ point(to_GAMA_CRS({plng, plat}, "EPSG:4326"));
							user_td <+ {plng, plat};
							DateTime <- location_data[2,r];
							// We can use data type Date instead.
							list<string> date_time <- split_with(DateTime, " ");
							userDate <+ date_time[0];
							userTime <+ date_time[1];
						}
						else{}

				}

				else{

						if ( point(to_GAMA_CRS({plng, plat}, "EPSG:4326")) overlaps rectangle(point(to_GAMA_CRS({-79.435067,43.644925}, "EPSG:4326")), point(to_GAMA_CRS({-79.359908,43.669973}, "EPSG:4326")))){//(lng between (-79.405138,-79.370119) and lat between (43.644856,43.659994)){
						user <+ point(to_GAMA_CRS({plng, plat}, "EPSG:4326"));
						user_td <+ {plng, plat};
						DateTime <- location_data[2,r];
						// we can use data type Date instead.
						list<string> date_time <- split_with(DateTime, " ");
						userDate <+ date_time[0];
						userTime <+ date_time[1];
						//date h <- date(date_time[1]);
					}	
					
				}
		}
		nb_people <- length(people);
		write "length of people= " + nb_people;
}
		
	
	action createTDs{
		cityMatrixData <- json_file(td_file_name).contents;	
		cityMatrixCell <- cityMatrixData["contents"];		
		cityMatrixCell <- remove_duplicates(cityMatrixCell);		
		loop l over: cityMatrixCell { 
			lng <- float(l["lon"]);
			lat  <- float(l["lat"]);
			loop p over: l["polygonpoints"]{
				add point(to_GAMA_CRS({float(p[0]), float(p[1])}, "EPSG:4326")) to:polygonpoints;

			}
						
			create td{
				address <- l["display_name"];
				location <- point(to_GAMA_CRS({lng, lat}, "EPSG:4326"));
				shape <- polygon(polygonpoints);
				
			}
			polygonpoints <- [];	
		}
	}

	
	action createBMO{
		cityMatrixData <- json_file(bmo_file_name).contents;
		cityMatrixCell <- cityMatrixData["contents"];
		cityMatrixCell <- remove_duplicates(cityMatrixCell);
		loop l over: cityMatrixCell { 
			lng <- float(l["lon"]);
			lat  <- float(l["lat"]);
			loop p over: l["polygonpoints"]{
				add point(to_GAMA_CRS({float(p[0]), float(p[1])}, "EPSG:4326")) to:polygonpoints;
			}
			
			create bmo{
				address <- l["display_name"];
				location <- point(to_GAMA_CRS({lng, lat}, "EPSG:4326"));
				shape <- polygon(polygonpoints);
				
			}
			polygonpoints <- [];	
		}
		
	}
	
	action createCIBC{
		cityMatrixData <- json_file(cibc_file_name).contents;
		cityMatrixCell <- cityMatrixData["contents"];		
		cityMatrixCell <- remove_duplicates(cityMatrixCell);		
		loop l over: cityMatrixCell { 
			lng <- float(l["lon"]);
			lat  <- float(l["lat"]);
			loop p over: l["polygonpoints"]{
				add point(to_GAMA_CRS({float(p[0]), float(p[1])}, "EPSG:4326")) to:polygonpoints;
			}			
			create cibc{
				address <- l["display_name"];
				location <- point(to_GAMA_CRS({lng, lat}, "EPSG:4326"));
				shape <- polygon(polygonpoints);
				
			}
			polygonpoints <- [];	
		}
	}
	
	action createTimHortons{
		cityMatrixData <- json_file(ths_file_name).contents;
		cityMatrixCell <- cityMatrixData["contents"];//cityMatrixData["candidates"];		
		cityMatrixCell <- remove_duplicates(cityMatrixCell);
		
		loop l over: cityMatrixCell { 
			lng <- float(l["lon"]);
			lat  <- float(l["lat"]);
			loop p over: l["polygonpoints"]{
				add point(to_GAMA_CRS({float(p[0]), float(p[1])}, "EPSG:4326")) to:polygonpoints;
			}
			
			create timHortons{
				address <- l["display_name"];
				location <- point(to_GAMA_CRS({lng, lat}, "EPSG:4326"));
				shape <- polygon(polygonpoints);
				
			}
			polygonpoints <- [];	
		}
	}

}

species name:amenity{
	image_file amenity_icon <-  file("../includes/bmo.jpg");
	string bank_name <- "";
	float latitude;
	float longitude;
	string address;
	int n_bmo_people;
	int peopleInsideThisBranch;
	image_file bmo_icon <- file("../includes/bmo.jpg") ;
	list<people> lp;
	list<string> uid;
	geometry loc;	
	float diffDate;
	
	user_command peopleInsideThisBranch{
		peopleInsideThisBranch <- length(agents_inside(self) of_species people);		
	}
	
	reflex name:peopleInsideTheBranch{
		lp <- (agents_inside(self) of_species people) where !(each.userid in uid);//agents_at_distance(10.0#m) of_species people; 
		loop p over:(lp) {
			if (!p.should_stop){
				p.notdeleted <- true;
				p.inbranch_location <- p.location CRS_transform("EPSG:4326");
				p.bankAddress <- replace(address,',','-');  
				p.bank <- bank_name;	
				
				if (p.bank_name != "" and p.bank_name != name){
					p.bank_name <- name;
					add p.dwell_time to:p.dwell_times;
					p.dwell_time <- 0.0;
				}	
				if (p.cnt != 0 and length(p.user_time) > 1){
	
					try{
						diffDate <- date(p.user_date[p.cnt]+"T" + p.user_time[p.cnt]) - date(p.user_date[p.cnt-1]+"T" + p.user_time[p.cnt-1]);//-d
					}
					catch{
						write " " + p.cnt + " - " + p.name + " - " + length(p.user_date);
					}
					p.dwell_time <- p.dwell_time + diffDate;
				}
			
			}
		}		
	}	
	
	aspect name:base{
		draw amenity_icon size: 250.0;
	}		
}

species name:td parent:amenity{
	init{
		amenity_icon <-  file("../includes/TD-bank-icon.png");
		bank_name <- "TD";	
	}	
}

species name:bmo parent:amenity{
	init{
		amenity_icon <-  file("../includes/bmo.jpg");
		bank_name <- "BMO";	
	}

}

species name:cibc parent:amenity{
	init{
		amenity_icon <-  file("../includes/cibc.jpg");
		bank_name <- "CIBC";	
	}
}

species name:timHortons parent:amenity{
	init{
		amenity_icon <-  file("../includes/timhortons.png");
		bank_name <- "THS";	
	}
}

species name:people skills:[moving]{
	list<point> agentMovementList <- [];
	list<string> user_date;
	list<string> user_time;
	list<point> users;
	list<point> user_TD_location;
	point inbranch_location;
	string userid;
	int id;
	float latitude;
	float longitude;
	bool notdeleted;
	string date_entered;
	string bankAddress;
	int idx <- 1;
	string bank;
	string bank_name;
	int cnt <- 0;
	float dwell_time;
	list<float> dwell_times;
	bool should_stop <- false; 
	point initLocation;
	
	reflex name:removeagentMovementList{
		agentMovementList  <- agentMovementList - first(agentMovementList);
		
	}
	
	reflex name:dead when:empty(agentMovementList){
		should_stop <- true;
		// people agents that are not withinn a location should be removed 
		if notdeleted = false{
			do die;
		}

	}
	
	reflex name:move when:!empty(agentMovementList){//} and length(agentMovementList)-1>0{
			cnt <- cnt + 1;
			idx <- length(agentMovementList);
			location <- first(agentMovementList);
		}		
	aspect name:base{
		draw shape color:#brown;// size: 250.0;
	}	
}

experiment main type: gui{

	output{
		display dis_td{
			//image ("../images/CITY-OF-TORONTO-map_rt.jpg") refresh: false;
			species td aspect:base refresh:false;
			species people aspect: base;
			species timHortons aspect:base refresh:false;
			species bmo aspect:base;
			species cibc aspect:base;
		}	
	}
}
