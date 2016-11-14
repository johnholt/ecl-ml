IMPORT Std;
IMPORT * FROM ML;
IMPORT ML.Tests.Explanatory as TE;
IMPORT * FROM ML.Types;
IMPORT * FROM TestingSuite.Utils;
IMPORT TestingSuite.Clustering as Clustering;

EXPORT TestKMeans(raw_dataset_name, repeats, no_clusters) := FUNCTIONMACRO
        AnyDataSet :=  raw_dataset_name;
 
        RunKMeans(DATASET(NumericField) dDocuments, DATASET(NumericField) dCentroids):= FUNCTION
                learner := ML.Cluster.KMeans(dDocuments,dCentroids, 100);  
                result := learner.Allegiances();
                RETURN SUM(result, value);
        END;
                

        
        WrapperRunKmeansClusterer(DATASET(RECORDOF(AnyDataSet)) AnyDataSet, number_of_clusters):= FUNCTION
                raw_dCentroidMatrix := DATASET(number_of_clusters, TRANSFORM(
                                                        RECORDOF(AnyDataSet), 
                                                        SELF := AnyDataSet[RANDOM() % COUNT(AnyDataSet)]));

                ToTraining(AnyDataSet, dDocumentMatrix);
                ToTraining(raw_dCentroidMatrix, dCentroidMatrix);                                                     
                                                       
                ML.ToField(dDocumentMatrix,dDocuments);
                ML.ToField(dCentroidMatrix,dCentroids);
                accuracy := RunKMeans(dDocuments, dCentroids);   
                RETURN accuracy;    
        END; 
        
        
        numberFormat := RECORD
                INTEGER run_id;
                REAL result;
        END;
        IMPORT Std;

        results := DATASET(#EXPAND(repeats),
                                        TRANSFORM(numberFormat,
                                        SELF.run_id := COUNTER;
                                        SELF.result := WrapperRunKmeansClusterer(raw_dataset_name, no_clusters);
                                        ));
        
        RETURN (REAL)AVE(results, results.result); 
ENDMACRO;


// TestKMeans(Clustering.Datasets.ionek_f_two_c_twoDS.content, 1, 2);

