IMPORT ML;
IMPORT $.Datasets;

EXPORT TestPorterStemC() := FUNCTION
    testValues := Datasets.PorterStemCDS;

    testResults := PROJECT
        (
            testValues,
            TRANSFORM
                (
                    RECORDOF(LEFT),

                    stemmedWord := ML.Docs.PorterStemC(LEFT.testStr);

                    SELF.actualStr := stemmedWord,
                    SELF.passed := stemmedWord = LEFT.expectedStr,
                    SELF := LEFT
                )
        );
    
    RETURN ROW
        (
            {
                COUNT(testValues),
                COUNT(testResults),
                COUNT(testResults(passed)),
                COUNT(testResults(~passed)),
                CHOOSEN(testResults(~passed), 100)
            },
            {
                UNSIGNED2   testValuesCnt,
                UNSIGNED2   numTests,
                UNSIGNED2   numPassed,
                UNSIGNED2   numFailed,
                DATASET(RECORDOF(testValues))   failSample
            }
        );
END;