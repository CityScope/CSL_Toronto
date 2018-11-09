/**
* Name: TD_dwellTime_osm_simulation
* Author: farzin
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model TD_dwellTime_osm_simulation

/* Insert your model definition here */

global {
	
	shape_file shape_city <- shape_file("../includes/2018_Vacant_Lands_with_PropertyPINS.shp") parameter: "shape";
    geometry shape <- envelope(shape_city);

    string url <-"http://localhost:8080";
    map<string, unknown> matrixData;
    string userId;
    int deviceType;
    int initOffset;
    int tdpeople <- 0;
    int cibcpeople <- 0;
    int bmopeople <- 0;
    int thspeople <- 0;
    
	string td_file_name <- "../includes/TDlocationBased/tdMississauga_locationBased_OSM_main.json";
	string bmo_file_name <- "../includes/TDlocationBased/bmoMississauga_locationBased_OSM_main.json";
	string cibc_file_name <- "../includes/TDlocationBased/cibcMississauga_locationBased_OSM_main.json";
	string ths_file_name <- "../includes/TDlocationBased/thsMississauga_locationBased_OSM_main.json";    
    
    list<td> tdBranches <- [];    
    	matrix<string,unknown> csvData;
    image_file torontoMap <- image_file("../images/toronto-downtown-with-buildings-map.jpg");//image_file("../images/CITY-OF-TORONTO-map_rt.jpg");
    
    
    	int nbofTD;
    	int nbofCIBC;
    	int nbofBMO;
    	int nbofTHS;
    	float spd <- 10.0;
	int day;
	
	init {
		create city from:shape_city;
	  	do createTDs;
	  	do createBMO;
	  	do createCIBC;
	  	do createTimHortons;	  		  	
	}

	
	action createTDs{	
		map<string, unknown> cityMatrixData;
		list<map<string, unknown>> cityMatrixCell;
		float lng;
		float lat;		
		list<point> polygonpoints <- [];

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
		map<string, unknown> cityMatrixData;
		list<map<string, unknown>> cityMatrixCell;	
		float lng;
		float lat;		
		list<point> polygonpoints <- [];

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
		map<string, unknown> cityMatrixData;
		list<map<string, unknown>> cityMatrixCell;
		float lng;
		float lat;		
		list<point> polygonpoints <- [];

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
		map<string, unknown> cityMatrixData;
		list<map<string, unknown>> cityMatrixCell;
		float lng;
		float lat;		
		list<point> polygonpoints <- [];

		cityMatrixData <- json_file(ths_file_name).contents;
		cityMatrixCell <- cityMatrixData["contents"];	
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
	
	reflex name:repeat when:(nbofTD=0 and nbofCIBC=0 and nbofBMO=0 and nbofTHS=0){
		day <- day + 1;
		if day > 31{
			do pause;
		}
		else{
			do createPeople(day);
		}
		
	}	
	
	
	action createPeople(int d){
		string monthday;
		string filename;
		int hour <- 0;
		write d;
				filename <- "Mississauga_201808_OSM" + d + ".csv";//"DowntownToronto_201808_OSM" + d + ".csv";//"Mississauga_201808" + d + ".csv";//"RichmondHill_201808" + d + ".csv";//
				write filename;
				create tdusers from:csv_file( "../results/osm/mississauga/td/" + filename,true) with:
					[userid::string(get("userid")), 
						latitude::float(get("inbranch_location.y")), 
						longitude::float(get("inbranch_location.x")),
						initlat::float(get("initLocation.y")),
						initlng::float(get("initLocation.x"))
		
					]{
						location <- point({initlng, initlat});
						the_target <-  point(to_GAMA_CRS({longitude, latitude}, "EPSG:4326"));//
						nbofTD <- nbofTD + 1;
					}
				create bmousers from:csv_file( "../results/osm/mississauga/bmo/"+filename,true) with:
					[userid::string(get("userid")), 
						latitude::float(get("inbranch_location.y")), 
						longitude::float(get("inbranch_location.x")),
						initlat::float(get("initLocation.y")),
						initlng::float(get("initLocation.x"))
					]{
						location <- point({initlng, initlat});
						the_target <-  point(to_GAMA_CRS({longitude, latitude}, "EPSG:4326"));//
						nbofBMO <- nbofBMO + 1;
					}
				create cibcusers from:csv_file( "../results/osm/mississauga/cibc/"+filename,true) with:
					[userid::string(get("userid")), 
						latitude::float(get("inbranch_location.y")), 
						longitude::float(get("inbranch_location.x")),
						initlat::float(get("initLocation.y")),
						initlng::float(get("initLocation.x"))						
		
					]{
						location <- point({initlng, initlat});
						the_target <-  point(to_GAMA_CRS({longitude, latitude}, "EPSG:4326"));//
						nbofCIBC <- nbofCIBC + 1;
					}	
				create thsusers from:csv_file( "../results/osm/mississauga/ths/"+filename,true) with:
					[userid::string(get("userid")), 
						latitude::float(get("inbranch_location.y")), 
						longitude::float(get("inbranch_location.x")),
						initlat::float(get("initLocation.y")),
						initlng::float(get("initLocation.x"))		
										
		
					]{

						location <- point({initlng, initlat});
						the_target <-  point(to_GAMA_CRS({longitude, latitude}, "EPSG:4326"));//
						nbofTHS <- nbofTHS + 1;
					}			
	}

}

species name:city schedules:[]{
	aspect base{
		draw shape color:#black;
	}
}


species name:amenity{

	int numberOfPeople;
	image_file my_icon;	
	geometry loc;
	int n_people;
	string address;
	
	user_command people_inside_branch {
		numberOfPeople <- length(agents_at_distance(10.0#m) of_species people);				
		loc <- shape CRS_transform("EPSG:4326");
	}


	aspect base {		
		draw  my_icon size: 250.0;
	}
	
}

species name:td parent:amenity{

	image_file my_icon <- file("../includes/TD-bank-icon.png") ;	


}

species name:bmo parent:amenity{

	image_file my_icon <- file("../includes/bmo.jpg") ;
	
}


species name:cibc parent:amenity{

	image_file my_icon <- file("../includes/cibc.jpg") ;
	
}


species name:timHortons parent:amenity{

	image_file my_icon <- file("../includes/timhortons.png") ;

}


species tdusers parent:people {

	
	reflex name:move when:the_target != nil{
		do goto target: the_target  speed:spd;
		if location with_precision 5 = the_target with_precision 5{
			the_target <- nil;
			ask world{
				tdpeople <- tdpeople + 1;
				nbofTD <- nbofTD - 1;	
			}
			// to mke the simulation faster
//			if day < 25 {
//					do die;
//			}
		}
	}

}


species cibcusers parent:people {
	
	reflex name:move when:the_target != nil{
		do goto target: the_target  speed:spd;
		if location with_precision 5 = the_target with_precision 5{
			the_target <- nil;
			ask world{
				cibcpeople <- cibcpeople + 1;
				nbofCIBC <- nbofCIBC - 1;												
			}
			// to mke the simulation faster
//			if day < 25 {
//					do die;
//			}
		}
	}

}

species bmousers parent:people {

	reflex name:move when:the_target != nil{
		do goto target: the_target  speed:spd;
		if location with_precision 5 = the_target with_precision 5{
			the_target <- nil;
			ask world{
				bmopeople <- bmopeople + 1;				
				nbofBMO <- nbofBMO -1;												
			}
			// to mke the simulation faster			
//			if day < 25 {
//					do die;
//			}
		}
	}

}

species thsusers parent:people {
	
	reflex name:move when:the_target != nil{
		do goto target: the_target  speed:spd;
		if location with_precision 5 = the_target with_precision 5{
			the_target <- nil;
			ask world{
				thspeople <- thspeople + 1;
				nbofTHS <- nbofTHS -1;												
			}
			// to mke the simulation faster
//			if day < 25 {
//					do die;
//			}
		}
	}

}


species name:people skills:[moving] {
	float longitude;
	float latitude;
	string userid;
	image_file my_icon <- file("../includes/person.png") ;
	point the_target;
	city building;
	int continue <- 1;
	float initlat;
	float initlng;
	
	aspect default {
		draw  my_icon size:325.0; //shape color:#black;//
	}
		
}


experiment main type: gui{
	
	//user_command "Athena" action:getAthenaData;

	output {
		display name:map refresh_every:1{
			//Toronto
			//image ("../images/CITY-OF-TORONTO-map_rt.jpg") refresh: false;
			//image ("../images/../images/toronto-downtown-with-buildings-map.jpg") refresh: false;

			
			//Mississauga
			//image ("../images/mississauga1.png") refresh: false;
			
			
			species city aspect:base;

			species td aspect:base;
			species bmo aspect:base;
			species cibc aspect:base;	
			species 	timHortons aspect:base;	
			species tdusers;
			species cibcusers;
			species bmousers;
			species thsusers;

			
			overlay position: { 5, 5 } size: { 300 #px, 150 #px } background: #black transparency: 1.0 border: #black 
            {
            	
                rgb text_color<-#green;
                float y <- 10#px;
  				draw "number of people in:" at: { 5#px, 20#px } color: #black font: font("Helvetica", 17, #bold) perspective:false;
                y <- y + 35 #px;
  				draw "TD branches: " + tdpeople at: { 10#px, y } color: rgb(52, 132, 2) font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 30 #px;
                draw "CIBC branches: " + cibcpeople at: { 10#px, y } color: rgb(229, 65, 57) font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 30 #px;
                draw "BMO branches: " + bmopeople at: { 10#px, y } color: rgb(1, 93, 163) font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 30 #px;
                draw "Tim Horton's: " + thspeople at: { 10#px, y } color: rgb(135, 20, 2) font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 60 #px;
                draw "Total number of people: " + (tdpeople+cibcpeople+bmopeople+thspeople) at: { 10#px, y } color: #black font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 50 #px;                
                draw "Month: August" at: { 10#px, y } color: rgb(1, 186, 183) font: font("Helvetica", 15, #bold) perspective:false;
                y <- y + 30 #px;
                if (day > 31){
                	day <- 31;
                }
                draw "Day:" + day at: { 10#px, y } color: rgb(1, 186, 183) font: font("Helvetica", 15, #bold) perspective:false;
            }
		}

	}

}