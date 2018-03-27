/**
  * Threshold Test
  *
  * This is the simplest Neural Network test.
  * 
  * Uses a linear 2-layer network [1,1]
  * Train the network to values above and below a threshold.
  * Test against the same values, and should indicate below or above.
  *
  */
import ML;
IMPORT ML.Mat;
IMPORT PBblas_v0;
NumericField := ML.Types.NumericField;
DiscreteField := ML.Types.DiscreteField;
Element := Mat.Types.Element;

UNSIGNED MaxIter := 50;
REAL8 ALPHA := 0.5;
REAL8 LAMBDA := .000001;
UNSIGNED DataRepeat := 100;
// Neural Network Structure (3 layers with 1 neuron)
dNetworkStructure := DATASET([
  {1, 1, 1},
  {2, 1, 1}
], ML.Types.DiscreteField);

// Create the training set.  Threshold is .1
ind0 := DATASET([{1,1,.09}, {2,1,.11}, {3, 1, .095}, {4, 1, .105}], NumericField);
ind := NORMALIZE(ind0, DataRepeat, TRANSFORM(RECORDOF(LEFT), SELF.id := (COUNTER-1) * 4 + LEFT.id, SELF := LEFT));
dep0 := DATASET([{1,1,0}, {2,1,1}, {3,1,0}, {4,1,1}], NumericField);
dep := NORMALIZE(dep0, DataRepeat, TRANSFORM(RECORDOF(LEFT), SELF.id := (COUNTER-1) * 4 + LEFT.id, SELF := LEFT));

// Instantiate Neural Network
NeuralNetwork := ML.NeuralNetworks(dNetworkStructure);


// Start with fixed weights for reproducibility
w1 := DATASET([{1, 1, -.0009}], Element);
w2 := DATASET([{1, 1, .0001}], Element);
IntW := Mat.MU.To(w1, 1) + Mat.MU.To(w2, 2);

b1 := DATASET([{1, 1, .006}], Element);
b2 := DATASET([{1, 1, -.04}], Element);
IntB := Mat.MU.To(b1, 1) + Mat.MU.To(b2, 2);


// Train Neural Network
NL := COUNT(dNetworkStructure);
mod := NeuralNetwork.NNLearn(ind, dep, IntW, IntB, LAMBDA, ALPHA, MaxIter);

OUTPUT(mod, NAMED('Mod'));

OUTPUT(NeuralNetwork.ExtractWeights(mod), NAMED('Weights'));

OUTPUT(NeuralNetwork.ExtractBias(mod), NAMED('Bias'));

// Test Cases -- In this simple test, we use test cases from the training set.
// Not a good idea in general, but we're testing the learning ability, not the generalization.
indTest := ind(id <= 4);
depTest := dep(id <= 4);
// Predict the results
pred := NeuralNetwork.NNClassify(indTest, mod);
OUTPUT(pred, NAMED('pred'));

// Compare accuracy
predAssess := JOIN(pred, depTest, LEFT.id = RIGHT.id,
                  TRANSFORM({UNSIGNED id, UNSIGNED pred, UNSIGNED expected, BOOLEAN isError},
                    SELF.isError := (LEFT.value != RIGHT.value),
                    SELF.pred := LEFT.value,
                    SELF.expected := RIGHT.value,
                    SELF.id := LEFT.id));

OUTPUT(predAssess, NAMED('Comparison'));

accuracy := COUNT(predAssess(isError = FALSE)) / 4;

OUTPUT(accuracy, NAMED('Accuracy'));
