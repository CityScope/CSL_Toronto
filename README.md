# CSL_Toronto
Repository for the CityScope project of Toronto City

## Models:
- TD_dwellTime_osm, reads TD's customers' location data from AWS-Athena (for now I read them locally due to a latency it caused (servers are located in East coast and I read them from West) and checks if people agents (customers) are inside a location (for example banks or coffee shops) and then put them into a file to be used by another model to be visualized. 
- TD_dwellTime_osm_simulation, reads the output created by the first one and display them. 
