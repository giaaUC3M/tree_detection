# Automatic individual tree detection from combination of aerial imagery, LiDAR and environment context
This project consists of **two parts**. In the first part, tree detections of the area of interest are obtained from lidar data. In the second part, using these detections and an orthophoto of the area of interest, we use a neural network model capable of detecting and georeferencing trees from orthophotos. 

The summary of this framework can be seen in the following image: 


![Framework Logo](/framework.svg "Framework")



## 1. LiDAR_detections
 * Programs:
    * R == 4.0.5
    * RStudio == 2021.9.03
   
   
The **inputs** of this program are the lidar data (.laz files) captured from the area of interest collected through the website of the national geographic information center http://centrodedescargas.cnig.es/CentroDescargas/catalogo.do?Serie=LIDAR.


* Required libraries:
   * LidR
   * Raster
   * Rgdal
* To use watershed algorithm:
   * From package "BiocManager"->"EBImage"
   * From package "gstat"->"gstat"    
    
    
## 2. Net_Trained_With_LiDAR_Detections
* Programs:
   * Google Drive
   * QGIS Desktop == 3.22.7


Note the location of the project in Google Drive, if it is not in the root of your drive you will have to modify the **path** variable of the code that allows you to locate the rest of the files.
You should also take this into account if you prefer to work locally instead of through Google Drive. 

The **inputs** of this program are:
* The output of the first part of the project (LiDAR_detections), i.e. the **tree detections obtained from lidar information** (.shp files).
* An **orthophoto** of the area where the lidar detections of the first part have been obtained, if you want to test the trained model you will also need an orthophoto of another area where you want to apply the model. Both orthophotos (.tif files) can be obtained from http://centrodedescargas.cnig.es/CentroDescargas/catalogo.do?Serie=VAMSB. 
* To **clean up the detections**, avoiding the confusion of trees with buildings or roads, we have used files that store the geometric entities of these objects (.shp files). To obtain this type of files you can do it through https://www.openstreetmap.org/export#map=16/40.5966/-3.9639&layers=T. You can follow the steps at https://tudelft3d.github.io/3dfier/building_footprints_from_openstreetmap.html.

All information on the **neural network architecture** used for training the tree detection model can be found at https://deepforest.readthedocs.io/en/latest/landing.html#:~:text=DeepForest%20uses%20deep%20learning%20object,models%20for%20tree%20detection%20simpler.

   
* Required libraries:
   * DeepForest==0.3.8
   * tensorflow-gpu==1.14.0
   * numpy
   * gdal-bin python3-gdal
   * scipy
   * pyshp
   * fiona==1.7
   * rasterio
   * pyproj
   * plotly==4.14.3
   * -U kaleido
   * pyyaml==5.4.1
