
########### READ ME ##########

#OPAM USER CALCULATION BY DR. OLIVER HIGGINS (olhiggin@tcd.ie)
#ENSURE THAT THE WORKING DIRECTORY IS 
#"SET TO SOURCE FILE LOCATION" BEFORE RUNNING
#(SESSION -> SET WORKING DIRECTORY -> TO SOURCE FILE LOCATION).

#TO RUN: CLICK "SOURCE" IN TOP BAR, OR SELECT WHOLE CODE (CMD+A) AND CLICK RUN.

#PACKAGES WILL BE INSTALLED AUTOMATICALLY IF NOT DETECTED.
#IF INSTALL PACKAGE PROMPTS APPEAR SELECT YES.

######## DO NOT CHANGE CODE BELOW THIS POINT ########

#packages and functions
pack1 <- suppressWarnings(require(terra, quietly = TRUE))
if(pack1 == FALSE) {install.packages("terra");library(terra, quietly = T)}
pack2 <- suppressWarnings(require(compositions, quietly = TRUE))
if(pack2 == FALSE) {install.packages("compositions");library(compositions, quietly = T)}
library(terra, quietly = T); library(compositions, quietly = T); rm(pack1); rm(pack2)
#clean environment if dirty
if(length(ls())>0){rm(list = ls())}
#Function and options
'%!in%' <- function(x,y)!('%in%'(x,y))
options(scipen=999)

##### LOAD DATA

#Load csv of user data
InputData <- suppressWarnings(as.data.frame(read.csv(file = "UserData.csv", header = T)))

#Load oxiparams
load("DO-NOT-DELETE/OxiParams.Rdata")

#load experimental datasets to check for saturation
load("DO-NOT-DELETE/SatExp.Rdata")

##### NORMALISE AND PERFORM CATION CALCULATIONS

#Isolate oxides from row headers and retain extra columns for later
all.ox <- rownames(OxiParams) 
ox <- all.ox[which(all.ox %in% colnames(InputData))]
if(length(which(ox%in% "H2O" == T))>0) {ox <- ox[-which(ox == "H2O")]}
#Isolate columns which are not oxides
not.ox <- which(colnames(InputData) %!in% ox)
if(length(not.ox)>0){ad.info <- InputData[,not.ox,drop=FALSE]}
#Retain just compositional info (additional columns added again at the end of the code if they exist)
CompData <- InputData[,ox]
#convert to numerics which will force weird characters or typos to NA
CompData <- as.data.frame(suppressWarnings(apply(CompData, 2, function(x){as.numeric(x)})))
if(nrow(InputData)==1){CompData <- as.data.frame(t(CompData));rownames(CompData) <- NULL}
#Deal with missing values for oxides
CompData[is.na(CompData)] <- 0
#Normalise to 100wt% anhydrous
CompData <- as.data.frame(t(apply(CompData, 1, function(x){(x/sum(x))*100})))

#Perform liquid cation calculation after Putirka 2008
OxPar <- OxiParams[ox,]
NewMolWeights <- round(OxPar$OWeight,2)/OxPar$Cat
molprop <- apply(CompData, MARGIN = 1, function(x) x / NewMolWeights)
molsums <- apply(molprop, MARGIN = 2, sum, na.rm = T)
cats <- as.data.frame(apply(molprop, MARGIN = 1, function(x) x/molsums))
if(nrow(InputData)==1){cats <- as.data.frame(t(cats));rownames(cats) <- NULL}
colnames(cats) <- OxPar$ElLabel
cats <- round(cats,4)

#Calculate additional parameters (ratios etc)
cats$MgNum <- (cats$Mg/(cats$Mg+cats$Fe2))*100
cats$CaNum <- cats$Ca/(cats$Ca+cats$Na)
cats$AlNum <- cats$Al/(cats$Al+cats$Si)
cats$Ca_Al <- cats$Ca/cats$Al
cats$Si_sq <- (cats$Si)^2
cats$Si_Ti <- cats$Si*cats$Ti

#Bind together user output
OutputData <- cbind(CompData, cats)

###### OXIDE FEATURES TO BE USED THROUGHOUT FOR ALL SATURATION TESTS

#Chosen features on which to run saturation tests (the ones reported in weber2023)
feat <- c("SiO2","TiO2","Al2O3","FeO","MgO","CaO","Na2O","K2O")

#Provide error message and stop code if an essential element is not included (i.e., is NA)
na.warn <- apply(InputData[,feat],2,function(x){sum(is.na(x))})
na.mess <- c("CALCULATION STOPPED: THERE ARE BLANK CELLS IN ESSENTIAL COLUMNS WHICH MUST HAVE A VALUE (GREATER THAN OR EQUAL TO ZERO). THESE COLUMNS ARE: SiO2, TiO2, Al2O3, FeO, MgO, CaO, Na2O, K2O")
if(sum(na.warn)>0){stop(na.mess)}

####### PERFORM FIRST-PASS CHULL TEST TO REMOVE OBVIOUS OUTLIERS AND INVALID DATA

#Subset outputdata to renormalise for chosen saturation oxides
SatTestData <- OutputData[,feat]

#rescale data for just chosen features
SatTestData <- as.data.frame(t(apply(SatTestData, 1, function(x){(x/sum(x))*100})))

#Relative percentage error to add for the OPAM experiments
exp.rel.er <- 5

#Subset opam-saturated experimental data
opam <- sat.exp[which(sat.exp$state.num==1),]

#create upper and lower bounds for experiments
opam.up <- opam[,feat]+(opam[,feat]*(exp.rel.er/100))
opam.low <- opam[,feat]-(opam[,feat]*(exp.rel.er/100))

#Find combinations of elements to chull
feat.df <- t(combn(x = feat, m = 2))

#Make a convex hull around the edge of the data including added uncertainty
chull.id <- list()
coord.ls <- list()
for(i in 1:nrow(feat.df)){
  f <- feat.df[i,]  
  x <- c(opam[,f[1]],opam[,f[1]],opam.low[,f[1]],opam.up[,f[1]]) 
  y <- c(opam.low[,f[2]],opam.up[,f[2]],opam[,f[2]],opam[,f[2]])
  chull.df <- data.frame(x,y)
  chull.id[[i]] <- chull(x = chull.df$x,y=chull.df$y)
  coord.ls[[i]] <- chull.df[chull.id[[i]],]
}
names(coord.ls) <- paste0(feat.df[,1], "-", feat.df[,2])

#chull check for checking if point lie in all 28 OPAM convex hulls
chull.test <- list()
for(i in 1:nrow(feat.df)){
#With SP
# chull.test[[i]] <-point.in.polygon(point.x = SatTestData[,feat.df[i,1]],point.y=SatTestData[,feat.df[i,2]],pol.x = coord.ls[[i]]$x, pol.y = coord.ls[[i]]$y)
#With Terra
x.pol <- coord.ls[[i]]$x; y.pol <- coord.ls[[i]]$y
pols <- vect(cbind(id=1, part=1, x.pol,y.pol), type="polygons")
x.pts <- SatTestData[,feat.df[i,1]]; y.pts <- SatTestData[,feat.df[i,2]]
pts <- vect(cbind(x.pts, y.pts))
poly.ext <- extract(pols, pts)
chull.test[[i]] <- as.integer(is.na(poly.ext[,2])==F)
#plot(uncomment line 136-line 141 if you want to see how the convex hull works)
# par(pty="s")
# sz <- as.vector(ext(pols))
# plot(x=opam[,feat.df[i,1]], y=opam[,feat.df[i,2]], xlab=feat.df[i,1], ylab=feat.df[i,2],
#      xlim=c(sz[1],sz[2]), ylim=c(sz[3],sz[4]), pch = 21, cex=0.5, bg="white", main=paste0("Chull",i))
# polygon(x=x.pol,y=y.pol,lty=2)
# points(x=x.pts,y=y.pts, pch=21, bg = "orange")
}
chull.test <- do.call(cbind,chull.test)
chull.sat <- rowSums(chull.test)>=nrow(feat.df)
#Amend chull test to output results
OutputData$InOPAMchull <- chull.sat

#### SCALE UNKNOWN DATA FOR SATURATION TEST

#Bind unknown and opam data
SatTestData$id <- "UNK"
sat.input <- rbind(SatTestData,sat.exp[,c(feat,"id")])

#scale unknown and opam data
scal <- as.data.frame(ilr(sat.input[,feat]))
colnames(scal) <- paste0("ilr",seq(1,length(feat)-1),"_scal")
sat.input <- cbind(sat.input,scal)
scal.nms <- colnames(scal)

######### USE EUCLIDIAN DISTANCE TO DISCRIMINATE SATURATION PROBABILITY

#Normalisation function
norm01 <- function(x){((x-min(x,na.rm = T))/(max(x,na.rm = T)-min(x,na.rm = T)))}

#calculate euclidian distance
mat <- as.matrix(dist(sat.input[,scal.nms],method = "euclidian"))
mat <- norm01(mat)
mat[mat == 0] <- NA

#resize distance matrix
mat <- as.matrix(mat[1:nrow(InputData), (nrow(InputData)+1):nrow(mat), drop=F])
colnames(mat) <- 1:nrow(sat.exp)

#Give the state a 1 or 0
state.num <- sat.exp$state.num

#Calculate saturation probability of test points
n <- 11
euc.id.ls <- list()
sat.vec <- NULL
unsat.vec <- NULL
pred.vec <- NULL
for(i in 1:nrow(SatTestData)) {
euc.sel <- sort(mat[i,], na.last = T)
euc.sel <- euc.sel[1:n] 
euc.id <- as.numeric(names(euc.sel))
euc.id.ls[[i]] <- euc.id
euc.state <- sat.exp$state.num[euc.id]
euc.wt <- (1-euc.sel)*(1/n)
p.sat <- sum(euc.wt[which(euc.state==1)])
sat.vec[i] <- p.sat
p.unsat <- sum(euc.wt[which(euc.state==0)])
unsat.vec[i] <- p.unsat
if(sat.vec[i]>=0.5){pred.vec[i] <- "SAT"}
if(sat.vec[i]<0.5){pred.vec[i] <- "UNSAT"}
# if(unsat.vec[i]>=params$sat.thresh[j] | sat.vec[i]<params$sat.thresh[j]){pred.vec[i] <- 0}
}

#Add results as column
OutputData$ProbSat <- round(sat.vec,3)
OutputData$State <- pred.vec

#Set any column which fails the chull test to unsaturated
OutputData$State[which(OutputData$InOPAMchull==FALSE)] <- "UNSAT"

##### PREDICT PRESSURE AND TEMPERATURE

#Load predict objects
load("DO-NOT-DELETE/pred_obj.Rdata")

#Predict temperature
OutputData$T_degC <- round(predict(object = pred_obj$t_mod, newdata = OutputData),0)
#Predict pressure
OutputData$P_kbar <- round(predict(object = pred_obj$p_mod, newdata = OutputData),2)

##### SAVE OUTPUT FILE

#Round oxides for tidyness of export (comment out to suppress rounding)
OutputData[,ox] <- round(OutputData[,ox],2)

#If additional columns exist, rebind
if(length(not.ox)>0){OutputData <- cbind(OutputData,ad.info)}

#create unique name
raw.nm <- format(Sys.time(), "-%d%b%y_%H-%M-%S")
nm.csv <- paste0("OutputData",raw.nm,".csv")
nm.rdata <- paste0("OutputData",raw.nm,".Rdata")

#Save as csv and Rdata
write.csv(x = OutputData, file = nm.csv, row.names = F)
save(x = OutputData, file = nm.rdata, row.names = F)
rm(list= ls()[!(ls() %in% c('OutputData','raw.nm'))])
print(paste0("CALCULATION IS COMPLETE. CHECK DIRECTORY FOLDER FOR OUTPUT FILES NAMED OutputData",raw.nm))



#LettersRBetterThanSnakes #pythOFF
