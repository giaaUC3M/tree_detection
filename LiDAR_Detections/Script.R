#install.packages("remotes")
#remotes::install_github("Jean-Romain/lidRplugins")
#library(lidRplugin)

# para utilizar watershed
install.packages("BiocManager") 
BiocManager::install("EBImage")
library(EBImage)
install.packages("gstat")
library(gstat)

#Librerias necesarias
library(lidR)
library(raster)
library(rgdal)

####################################################################################################
# Selecci�n de datos LiDAR a leer
####################################################################################################
workspace = "./"
workspaceInput = "./LiDAR_Cloud_Points/" # Colmenarejo RGB
workspaceOutputSHP = paste(workspace, "", "LiDAR_Detections", sep="")
if (!dir.exists(workspaceOutputSHP)){
  dir.create(workspaceOutputSHP)
}

file_list <- list.files(path=workspaceInput) # create a list of the files from your target directory

####################################################################################################
# Selecci?n algoritmos a utilizar
####################################################################################################
  # 1 = knnidw
  # 2 = kriging
  # 3 = tin
dtmAlgorithmUseValues              = c(1)
  # 1 = pitfree
  # 2 = dsmtin
  # 3 = p2r
chmAlgorithmUseValues              = c(3)
  # 1 = lmf1
  # 2 = lmf2
  # 3 = None
treeLocationAlgorithmUseValues     = c(2)
  # 1 = dalponte2016
  # 2 = li2012
  # 3 = watershed, install packages!!
  # 4 = silva2016
treeSegmentationAlgorithmUseValues = c(4) 

#had to specify columns to get rid of the total column
for (i in seq_along(file_list)){ # 10:20){
  for (dtmAlgorithmUse in dtmAlgorithmUseValues){
    for (chmAlgorithmUse in chmAlgorithmUseValues){
      for (treeLocationAlgorithmUse in treeLocationAlgorithmUseValues){
        for (treeSegmentationAlgorithmUse in treeSegmentationAlgorithmUseValues){
          ####################
          # Gesti?n de carpetas
          ####################
          nameNoExtension = strsplit(file_list[i], "\\.")[[1]]
          nameNoExtension = nameNoExtension[1]
          
          outputName = paste(nameNoExtension, "_", 
                             dtmAlgorithmUse, "_", 
                             chmAlgorithmUse, "_", 
                             treeLocationAlgorithmUse, "_", 
                             treeSegmentationAlgorithmUse,
                             sep = "")
          
          print("*****************************************************************")
          print(outputName)
          
          ####################
          # Carga de datos LiDAR
          ####################
          fullpath = paste(workspaceInput, file_list[i], sep = "")
          lidar <- readLAS(fullpath)
          
          ####################
          # Resumen y comprobaci?n de los datos lidar
          ####################
          #las_check(lidar)
          #summary(lidar)
          
          ####################
          # Visualizaci?n de los puntos clasificados como vegetaci?n media-alta
          ####################
          #las_class(lidar, Classification == 5) # No funciona??
          #plot(las_class)
          
          ####################
          # Aplicaci?n de un filtro en los datos lidar para separar los puntos relacionados ?nicamente con suelo y vegetaci?n
          ####################
          las2 <- readLAS(fullpath, filter="-keep_class 2 5")
          
          ####################
          # Obtenci?n Digital Terrain Model (DTM)
          # Normaliza la altura de los puntos
          ####################
          # Selecci?n del algoritmo
          if(dtmAlgorithmUse == 1){
            dtmAlgorithm = knnidw( 
              k=8,       # integer. Number of k-nearest neighbours. Default 10.
              p=2,       # numeric. Power for inverse-distance weighting. Default 2.
              rmax = 50  # numeric. Maximum radius where to search for knn. Default 50
            )
          } else if(dtmAlgorithmUse == 2){
            dtmAlgorithm = kriging(
              model = gstat::vgm(0.59, "Sph", 874), # A variogram model computed with vgm. If NULL it performs an ordinary or weighted least squares prediction.
              k = 10L                               # numeric. Number of k-nearest neighbours. Default 10.
            )
          } else if(dtmAlgorithmUse == 3){
            dtmAlgorithm = tin(
              extrapolate = knnidw(3, 1, 50) # There are usually a few points outside the convex hull, determined by the ground points at the very edge of the dataset, that cannot be interpolated with a triangulation. Extrapolation is done using the nearest neighbour approach by default using knnidw.
            )
          }
          
          # Aplicaci?n del algoritmo
          dtm <- grid_terrain(las2, algorithm = dtmAlgorithm)
          las_normalized <- normalize_height(las2, dtm)
          
          ####################
          # Obtenci?n del Canopy Height Model (CHM)
          ####################
          # Selecci?n del algoritmo
          if(chmAlgorithmUse == 1){
            chmAlgorithm = pitfree(
              thresholds = c(0,2,5,10,15), # numeric. Set of height thresholds according to the Khosravipour et al. (2014) algorithm description (see references)
              max_edge = c(3,1.5),         # numeric. Maximum edge length of a triangle in the Delaunay triangulation. If a triangle has an edge length greater than this value it will be removed. The first number is the value for the classical triangulation (threshold = 0, see also dsmtin), the second number is the value for the pit-free algorithm (for thresholds > 0). If max_edge = 0 no trimming is done (see examples).
              subcircle = 0.2              # numeric. radius of the circles. To obtain fewer empty pixels the algorithm can replace each return with a circle composed of 8 points (see details).
            )
          } else if(chmAlgorithmUse == 2){
            chmAlgorithm = dsmtin(
              max_edge = 0 # numeric. Maximum edge length of a triangle in the Delaunay triangulation. If a triangle has an edge length greater than this value it will be removed to trim dummy interpolation on non-convex areas. If max_edge = 0 no trimming is done (see examples).
            )
          } else if(chmAlgorithmUse == 3){
            chmAlgorithm = p2r(
              subcircle = 0,  # numeric. Radius of the circles. To obtain fewer empty pixels the algorithm can replace each return with a circle composed of 8 points (see details).
              na.fill = NULL  # function. A function that implements an algorithm to compute spatial interpolation to fill the empty pixel often left by points-to-raster methods. lidR has knnidw, tin, and kriging (see also grid_terrain for more details).
            )
          }
          
          # Aplicaci?n del algoritmo
          chm <- grid_canopy(las_normalized, 0.5, chmAlgorithm)
          
          # Visualizaci?n del CHM
          #plot_dtm3d(chm)
          
          
          ####################
          # Localizaci?n copa de los ?rboles
          ####################
          if(treeLocationAlgorithmUse == 1){
            f <- function(x) { x * 0.07 + 3 }
            treeLocationAlgorithm = lmf(
              ws=f,
              hmin = 2,
              shape="circular"
            )
          } else if(treeLocationAlgorithmUse == 2){
            f <- function(x) { x * 0.07 + 3 }
            treeLocationAlgorithm = lmf(
              ws=3
            )
          } else if(treeLocationAlgorithmUse == 3){
            
          }
          
          # Aplicaci?n del algoritmo
          treetops <- find_trees(las_normalized, treeLocationAlgorithm)
          
          # PARA????
          ker <- matrix (1,5,5)
          chm_s <- focal(chm, w=ker, fun=median)
          
          
          ##################### 
          # Aplicaci?n algoritmo segmentaci?n arboles
          ####################
          if(treeSegmentationAlgorithmUse == 1){
            treeSegmentationAlgorithm = dalponte2016(
              chm,              # RasterLayer. Image of the canopy. Can be computed with grid_canopy or read from an external file.
              treetops,         # SpatialPointsDataFrame. Can be computed with find_trees or read from an external shapefile.
              th_tree = 2,      # numeric. Threshold below which a pixel cannot be a tree. Default is 2.
              th_seed = 0.45,   # numeric. Growing threshold 1. See reference in Dalponte et al. 2016. A pixel is added to a region if its height is greater than the tree height multiplied by this value. It should be between 0 and 1. Default is 0.45.
              th_cr   = 0.55,   # numeric. Growing threshold 2. See reference in Dalponte et al. 2016. A pixel is added to a region if its height is greater than the current mean height of the region multiplied by this value. It should be between 0 and 1. Default is 0.55.
              max_cr  = 10,     # numeric. Maximum value of the crown diameter of a detected tree (in pixels). Default is 10.
              ID = "treeID"     # character. If the SpatialPointsDataFrame contains an attribute with the ID for each tree, the name of this attribute. This way, original IDs will be preserved. If there is no such data trees will be numbered sequentially.
            )
          } else if(treeSegmentationAlgorithmUse == 2){
            treeSegmentationAlgorithm = li2012(
              dt1 = 1.5,     # numeric. Threshold number 1. See reference page 79 in Li et al. (2012). Default is 1.5.
              dt2 = 2,       # numeric. Threshold number 2. See reference page 79 in Li et al. (2012). Default is 2.
              R = 2,         # numeric. Search radius. See page 79 in Li et al. (2012). Default is 2. If R = 0 all the points are automatically considered as local maxima and the search step is skipped (much faster).
              Zu = 15,       # numeric. If point elevation is greater than Zu, dt2 is used, otherwise dt1 is used. See page 79 in Li et al. (2012). Default is 15.
              hmin=2,        # numeric. Minimum height of a detected tree. Default is 2.
              speed_up = 5   # numeric. Maximum radius of a crown. Any value greater than a crown is good because this parameter does not affect the result. However, it greatly affects the computation speed. The lower the value, the faster the method. Default is 10
            )
          } else if(treeSegmentationAlgorithmUse == 3){
            treeSegmentationAlgorithm = watershed(
              chm,           # RasterLayer. Image of the canopy. Can be computed with grid_canopy or read from an external file.
              th_tree = 2,   # numeric. Threshold below which a pixel cannot be a tree. Default is 2.
              tol     = 1,   # numeric. Tolerance see ?EBImage::watershed.
              ext     = 1    # numeric. see ?EBImage::watershed.
            )
          } else if(treeSegmentationAlgorithmUse == 4){
            treeSegmentationAlgorithm = silva2016(
              chm,                  # RasterLayer. Image of the canopy. Can be computed with grid_canopy or read from an external file.
              treetops,             # SpatialPointsDataFrame. Can be computed with find_trees or read from an external shapefile.
              max_cr_factor = 0.6,  # numeric. Maximum value of a crown diameter given as a proportion of the tree height. Default is 0.6, meaning 60% of the tree height.
              exclusion     = 0.3,  # numeric. For each tree, pixels with an elevation lower than exclusion multiplied by the tree height will be removed. Thus, this number belongs between 0 and 1.
              ID = "treeID"         # character. If the SpatialPointsDataFrame contains an attribute with the ID for each tree, the name of this column. This way, original IDs will be preserved. If there is no such data trees will be numbered sequentially.
            )
          }
          
          # Aplicaci?n del algoritmo
          trees <- segment_trees(las_normalized, treeSegmentationAlgorithm)
          
          # Visualizaci?n del resultado
          #plot(trees, color = "treeID")
          
          
          ####################
          # Obtenci?n de bounding boxes
          ####################
          hulls <- delineate_crowns(trees, "bbox")
          metrics <- tree_metrics(trees, attribute = "treeID")
          plot(hulls)
          
          ####################
          # Escritura de CSV/SHP
          ####################
          writeOGR(
            obj    = hulls,
            dsn    = workspaceOutputSHP,
            layer  = outputName,
            driver = "ESRI Shapefile"
          )
          
          
        }
      }
    }
  }
}
