/**
  * XOR Test
  *
  * Train the network to an XOR function and output the weights, biases, numeric predictions (i.e. probabilities),
  * and class predictions (i.e. 0 or 1).  A network with at least one hidden layer is required to solve XOR.
  *
  */
import ML;
import ML.Types;

DiscreteField := Types.DiscreteField;

// Note: The following parameters should always work 100%.
// ALPHA = .5
// LAMBDA = .000001
// MaxIter = 10
// DataRepeat = 100
// Network [2, 2, 2]
REAL8 ALPHA := 0.5; // Alpha is the learning-rate
REAL8 LAMBDA := 0.000001;
UNSIGNED MaxIter := 10;
UNSIGNED DataRepeat := 100;
// Neural Network Structure (3 layers with 2 neurons each)
dNetworkStructure := DATASET([
  {1, 1, 2},
  {2, 1, 2},
  {3, 1, 2}
], ML.Types.DiscreteField);

// XOR elements layout (inputs and outputs)
lSample := RECORD
  UNSIGNED id;
  REAL x1;
  REAL x2;
  REAL sum;
  REAL carry;
END;

// XOR truth table cases
dSeed := DATASET([{1, 0, 0}, {2, 0, 1}, {3, 1, 0}, {4, 1, 1}], {UNSIGNED id, UNSIGNED1 a, UNSIGNED1 b});
dSample0 := NORMALIZE(dSeed, DataRepeat, TRANSFORM(lSample,
                SELF.id := (COUNTER-1) * 4 + LEFT.id,
                SELF.x1 := LEFT.a,
                SELF.x2 := LEFT.b,
                SELF.sum := LEFT.a ^ LEFT.b,
                SELF.carry := LEFT.a & LEFT.b));

dSample := SORT(dSample0, id); // Make sure the seeds are repeated sequentially, and not all of one seed in a row

OUTPUT(dSample, NAMED('TrainingSet'));
// Independent Variables Layout
lInput := RECORD
  dSample.id;
  dSample.x1;
  dSample.x2;
END;

// Dependent Variables Layout
lLabel := RECORD
  dSample.id;
  dSample.sum;
  dSample.carry;
END;

lAssess := RECORD(lLabel)
  BOOLEAN isError;
END;

// Indep Data
dInput := TABLE(dSample, lInput);
// Dep Data
dLabel := TABLE(dSample, lLabel);

// Convert deps and indeps to NumericField format
ML.ToField(dInput, vInput);
ML.ToField(dLabel, vLabel);

// Instantiate Neural Network
NeuralNetwork := ML.NeuralNetworks(dNetworkStructure);


IntW := NeuralNetwork.IntWeights;
IntB := NeuralNetwork.IntBias;
OUTPUT(IntW, NAMED('IntW'));
// Train Neural Network
LearntModel := NeuralNetwork.NNLearn(vInput, vLabel, IntW, IntB, LAMBDA, ALPHA, MaxIter);

OUTPUT(NeuralNetwork.ExtractWeights(LearntModel), NAMED('Weights'));
OUTPUT(NeuralNetwork.ExtractBias(LearntModel), NAMED('Bias'));

// Test Cases
dTest := DATASET([
  {1, 0, 0},
  {2, 0, 1},
  {3, 1, 0},
  {4, 1, 1}
  ], lInput);
ML.ToField(dTest, vTest);

expected := DATASET([{1, 0, 0}, {2, 1, 0}, {3, 1, 0}, {4, 0, 1}],
                    lLabel);

probs := NeuralNetwork.NNoutput(vTest, LearntModel);
OUTPUT(probs, NAMED('probs'));

// Classify Test Case
pred := NeuralNetwork.NNClassify(vTest, LearntModel);
OUTPUT(pred, NAMED('Predictions'));

ML.FromField(pred, lLabel, rPred);

// Assess the correctness
predAssess := JOIN(rPred, expected, LEFT.id = RIGHT.id,
                      TRANSFORM(lAssess,
                        SELF.isError := (LEFT.sum != RIGHT.sum OR LEFT.carry != RIGHT.carry),
                        SELF := LEFT));


// Format results -- Input + Prediction + Assessment
dResult := JOIN(dTest, predAssess, LEFT.id = RIGHT.id, TRANSFORM({lInput, lAssess},
  SELF := LEFT;
  SELF := RIGHT;
));

dPrettyResult := SORT(dResult, id);
OUTPUT(dPrettyResult, NAMED('Compare'));

accuracy := COUNT(dResult(isError = FALSE)) / 4;

OUTPUT(accuracy, NAMED('Accuracy'));