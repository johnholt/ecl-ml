// K-MEANS EXAMPLE
//
// Presents K-Means clustering in a 2-dimensional space. 100 data points
// are initialized with random values on the x and y axes, and 4 centroids
// are initialized with values assigned to be regular but non-symmetrical.
//
// The sample code shows how to determine the new coordinates of the
// centroids after a user-defined set of iterations. Also shows how to
// determine the "allegiance" of each data point after those iterations.
//---------------------------------------------------------------------------

IMPORT ML;
IMPORT ML.Types as Types;
IMPORT ML.Mat as Mat;
IMPORT excercise.uscensus as uscensus;

//USCENSUS data
dDocumentMatrix := uscensus.input;

//The length of USCENSUSD data
dDoc_len := COUNT(dDocumentMatrix);

//Define the number of clusters K and the number of groups G for YinyangKmeans Algorithm
k := 100;
g := k/10;

//The maximum number of iterations
ite :=100;

//Generate reamdom number within a specified range
INTEGER ranger(INTEGER lower, INTEGER upper) := FUNCTION
RETURN lower + random()% (upper - lower);
END;

d := record
INTEGER id;
END;

//Initial Centroids
kSet := DATASET(k, TRANSFORM(d, SELF.id := ranger(1, dDoc_len)));
OUTPUT(kset, , '~lili::kset' + RANDOM());
dCentroidMatrix := dDocumentMatrix(dDocumentMatrix.id IN SET(kSet,id));

//Initial Groups
gSet := DATASET(g, TRANSFORM(d, SELF.id := RANDOM()%k));
dGt := PROJECT(gSet, transform(RECORDOF(dCentroidMatrix), self := dCentroidMatrix[left.id]));


ML.ToField(dDocumentMatrix,dDocuments);
ML.ToField(dCentroidMatrix,dCentroids);
ML.ToField(dGt, dt)

                                                                              // EXAMPLES
KMeans:=ML.Cluster.KMeans(dDocuments,dCentroids,ite,.3);                      // Set up KMeans with a maximum of 30 iterations and .3 as a convergence threshold
KMeans.Allresults;                                                            // The table that contains the results of each iteration
KMeans.Convergence;                                                           // The number of iterations it took to converge


YinyangKMeans:=ML.Cluster.YinyangKMeans(dDocuments,dCentroids,dt,ite,0.3); 		// Set up YinYangKMeans with a maximum of 30 iterations and .3 as a convergence threshold
YinyangKMeans.Allresults;                                       					    // The table that contains the results of each iteration
YinyangKMeans.Convergence;                                      					    // The number of iterations it took to converge

