//RandomForest.ecl
IMPORT Std;
IMPORT * FROM ML;
IMPORT ML.Tests.Explanatory as TE;
IMPORT * FROM ML.Types;
IMPORT * FROM TestingSuite.Utils;
IMPORT TestingSuite.Classification as Classification;

EXPORT TestLogisticRegression(raw_dataset_name, repeats) := FUNCTIONMACRO
	//STRING dataset_name := 'Classification.Datasets.' + raw_dataset_name + '.content';
	AnyDataSet :=  TABLE(raw_dataset_name);

	RunLogisticRegression(DATASET(DiscreteField) trainIndepData, DATASET(DiscreteField) trainDepData, DATASET(DiscreteField) testIndepData, DATASET(DiscreteField) testDepData) := FUNCTION
			learner := Classify.Logistic();  
			result := learner.LearnC(trainIndepData, trainDepData); 
			class:= learner.ClassifyC(testIndepData, result); 
			performance:= Classify.Compare(testDepData, class);
			return performance.Accuracy[1].accuracy;
		END;



	WrapperRunLogisticRegression(DATASET(RECORDOF(AnyDataSet)) AnyDataSet):= FUNCTION

		// To create training and testing sets
		new_data_set := TABLE(AnyDataSet, {AnyDataSet, select_number := RANDOM()%100});


		raw_train_data := new_data_set(select_number <= 40);
		raw_test_data := new_data_set(select_number > 40);

		// Splitting data into train and test	
		ToTraining(raw_train_data, train_data_independent);
		ToTesting(raw_train_data, train_data_dependent);
		ToTraining(raw_test_data, test_data_independent);
		ToTesting(raw_test_data, test_data_dependent);

		ToField(train_data_independent, trainIndepData);
		ToField(train_data_dependent, trainDepData);

		ToField(test_data_independent, testIndepData);
		ToField(test_data_dependent, testDepData);
		
		result := RunLogisticRegression(trainIndepData, trainDepData, testIndepData, testDepData);
		return result;
	END;


	numberFormat := RECORD
		INTEGER run_id;
		REAL result;
	END;
	IMPORT Std;

	results := DATASET(#EXPAND(repeats),
							TRANSFORM(numberFormat,
							SELF.run_id := COUNTER;
							SELF.result := WrapperRunLogisticRegression(AnyDataSet);
							));


	RETURN (REAL)AVE(results, results.result); 
ENDMACRO;

//OUTPUT(TestRandomForestClassification(Classification.Datasets.ecoliDS.content, 3));
