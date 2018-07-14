IMPORT ML;
IMPORT ML.Mat;
IMPORT ML.Types AS Types;
IMPORT PBblas_v0;
IMPORT ML.DMat AS DMat;
Layout_Cell := PBblas_v0.Types.Layout_Cell;
Layout_Part := PBblas_v0.Types.Layout_Part;
NumericField := Types.NumericField;
MUElement := Mat.Types.MUElement;

/**
  * Neural Network Machine Learning Module
  *
  * This module is based on Stanford deep learning tutorial (http://ufldl.stanford.edu/wiki/index.php/Neural_Networks)
  * Note that there is an error in the tutorial that was recently uncovered: The tutorial specifies passing all of
  * the data records to Back-propagation and then adjusting weights, while it is, in fact, necessary to adjust the
  * weights and biases after each sample.
  *
  * The 'net' parameter specifies the shape of the neural network as a dataset of DiscreteField.  Note that this
  * includes the input and output layer as well as any needed hidden layers.
  * The size of the first layer will be the same as the number of input features.  The size of the
  * last layer will be the same as the number of outputs, while the hidden layer sizes can be any size greater
  * than 0.  The more complex a problem, the more hidden layers will be required, and the larger the size of the
  * hidden layers.  The shape of the network is specified using the DiscreteField layout: {id, number, value}.
  * The id field is the layer number (starting with 1).  The number field should always be set to '1'. The value
  * field contains the number of neurons in the given layer.  So, to specify a network with no hidden layers,
  * 2 inputs and one output, you would specify:
  * DATSET([{1, 1, 1},
  *         {2, 1, 2}], DiscreteField);
  * To specify a network with two inputs, two outputs and a single hidden layer with six neurons:
  * DATASET([{1, 1, 2},
  *          {2, 1, 6},
  *          {3, 1, 2}], DiscreteField);
  *
  * Note that it is best to use the smallest network that will solve your problem.  Larger networks are
  * susceptible to overfitting and local minima, and can take a very long time to train.
  *
  * The typical flow for an application is to use NNLearn(...) to build a model (i.e. determine best weights and
  * bias for each neuron), and then to use that model to predict values using NNPredict(...) or NNClassify(...).
  *
  * The attributes IntWeights and IntBias are typically called to provide random starting points for the weights
  * and biases of the network (passed to NNLearn).  These values can be persisted and used with NNLearn to
  * get exactly repeatable results.  More typically, they are called on each run to give a random starting point,
  * which will typically produce similar, but not identical results on each run.
  *
  * Note that there are four additional optional parameters that can be passed for backward compatibility reasons that
  * are currently unused in the implementations, and are therefore not described here.
  *
  * @param net The shape of the neural network (see description above)
  *
  */
EXPORT NeuralNetworks (DATASET(Types.DiscreteField) net,
                       UNSIGNED4 prows=0, UNSIGNED4 pcols=0, UNSIGNED4 Maxrows=0, UNSIGNED4 Maxcols=0) := MODULE

//initialize bias values in the neural network
//each bias matrix is a vector
//bias with no=L means the bias that goes to the layer L+1 so its size is equal to number of nodes in layer L+1
  /**
    * Generate a random starting point for the bias (IntB) parameter to NNLearn
    * These may be persisted and used in future runs if exactly repeatable results are
    * needed.
    *
    * @return A dataset of biases in Mat.Types.MUElement format.  The 'no' field indicates
    *         the layer(L), the 'x' field represents the neuron number in layer (L+1) to which
    *         the bias applies, and the
    *         'y' field is unused.  The 'value' field is the initial bias value.
    */
  EXPORT IntBias := FUNCTION
    // Note: B(L, i) is the bias for node i in L+1.  The 'no' field represents L, the x field represents i,
    //   and the y field is unused and set to 1.
    // Random Matrix Generator
    Mat.Types.Element RandGen(UNSIGNED4 c, UNSIGNED4 NumRows) := TRANSFORM
      SELF.x := ((c-1) % NumRows) + 1;
      SELF.y := ((c-1) DIV NumRows) + 1;
      SELF.value := RANDOM()%1000000 / 100000000 - .005;  // Uniform [-.005, .005]
    END;
    //Create the first weight matrix with no=1 (weight matrix between layer 1 and layer 2)
    b1rows := net(id=(2))[1].value;
    b1cols := 1;
    b1size := b1rows*b1cols;
    b1 := DATASET(b1size, RandGen(COUNTER, b1rows),DISTRIBUTED);
    b1no := Mat.MU.To(b1, 1);
    //step function for initialize the rest of the weight matrices
    Step(DATASET(Mat.Types.MUElement) InputBias, INTEGER coun) := FUNCTION
      L := coun+1; //create the weight between layers L and L+1
      brows := net(id=(L+1))[1].value;
      bcols := 1;
      bsize := brows*bcols;
      b := DATASET(bsize, RandGen(COUNTER, brows),DISTRIBUTED);
      bno := Mat.MU.To(b, L);
      RETURN InputBias+bno;
    END;
    LoopNum := MAX(net,id)-2;
    initialized_Bias := LOOP(b1no, COUNTER <= LoopNum, Step(ROWS(LEFT),COUNTER));
  RETURN initialized_Bias;
  END;
  /**
    * Generate a random starting point for the weights (IntW) parameter to NNLearn.
    * These may be persisted and used in future runs if exactly repeatable results are
    * needed.
    *
    * @return A dataset of weights in Mat.Types.MUElement format.  
    *         Each weight (W(L, j, i)) represents the weight between neuron j in layer L
    *         and neuron i in L+1. The 'no' field indicates
    *         the layer(L), the 'x' field represents the neuron number in layer L+1 (i.e. i), and the
    *         'y' field is the neuron number in layer L.  The 'value' field is the initial weight.
    */
  EXPORT IntWeights := FUNCTION
    // Note: W(L, j, i) is the weight between node j in L and node i in L+1
    //  The 'no' field represents L, the x field represents i, and the y field represents j.
    //Generate a random number
    Produce_Random () := FUNCTION
      G := 1000000;
      R := (RANDOM()%G) / (REAL8)(G*100) -.005; // Uniform [-.005, .005]
      RETURN R;
    END;
    //New Randome Matrix Generator
    Mat.Types.Element RandGen(UNSIGNED4 c, UNSIGNED4 NumRows) := TRANSFORM
      SELF.x := ((c-1) % NumRows) + 1;
      SELF.y := ((c-1) DIV NumRows) + 1;
      SELF.value := Produce_Random();
    END;
    //Create the first weight matrix with no=1 (weight matrix between layer 1 and layer 2)
    w1rows := net(id=2)[1].value;
    w1cols := net(id=1)[1].value;
    w1size := w1rows*w1cols;
    w1 := DATASET(w1size, RandGen(COUNTER, w1rows),DISTRIBUTED);
    w1no := Mat.MU.To(w1, 1);
    //step function for initialize the rest of the weight matrices
    Step(DATASET(Mat.Types.MUElement) InputWeight, INTEGER coun) := FUNCTION
      L := coun+1; //creat the weight between layers L and L+1
      wrows := net(id=(L+1))[1].value;
      wcols := net(id=L)[1].value;
      wsize := wrows*wcols;
      w := DATASET(wsize, RandGen(COUNTER, wrows),DISTRIBUTED);
      wno := Mat.MU.To(w, L);
      RETURN InputWeight+wno;
    END;
    LoopNum := MAX(net,id)-2;
    initialized_weights := LOOP(w1no, COUNTER <= LoopNum, Step(ROWS(LEFT),COUNTER));
    RETURN initialized_weights;
  END;
  /**
    * Convert the model from numeric field format to RECORDOF(id, x, y, value, no)
    *
    * @param mod A model as returned from NNLearn in DATASET(NumericField) format
    * @return The model converted to record oriented form.
    *
    */
  //in the built model the no={1,2,..,NL-1} are the weight indexes
  //no={NL+1,NL+2,..,NL+NL} are bias indexes that go to the second, third, ..,NL)'s layer respectively
  EXPORT Model(DATASET(Types.NumericField) mod) := FUNCTION
    modelD_Map :=	DATASET([{'id','ID'},{'x','1'},{'y','2'},{'value','3'},{'no','4'}], {STRING orig_name; STRING assigned_name;});
    ML.FromField(mod,Mat.Types.MUElement,dOut,modelD_Map);
    RETURN dOut;
  END;
  /**
    * Extract the set of weights from a model returned from NNLearn
    */
  EXPORT ExtractWeights (DATASET(Types.NumericField) mod) := FUNCTION
    NNmod := Model (mod);
    NL := MAX (net, id);
    RETURN NNmod (no<NL);
  END;
  /**
    * Extract the set of biases from a model returned from NNLearn
    */
  EXPORT ExtractBias (DATASET(Types.NumericField) mod) := FUNCTION
    NNmod := Model (mod);
    NL := MAX (net, id);
    B := NNmod (no>NL);
    Mat.Types.MUElement Sno (Mat.Types.MUElement l) := TRANSFORM
      SELF.no := l.no-NL;
      SELF := l;
    END;
    RETURN PROJECT (B,Sno(LEFT));
  END;
  /*
  Back-propagation algorithm
  implementation based on stanford deep learning tutorial (http://ufldl.stanford.edu/wiki/index.php/Neural_Networks)
  X is input data
  w and b represent the structure of neural network
  w represents weight matrices : matrix with no=L means the weight matrix between layer L and layer L+1
  w(j,i) with no=L represents the weight between unit j of layer L and i of layer L+1
  b represent bias matrices
  b with no = L shows the bias value for the layer L+1
  b(i) with no= L shows the bias value that goes to unit i of layer L+1
  Note that this form of BP is not parallelizable and will run somewhat slower on thor than hthor.
  */
  SHARED BP(DATASET(Types.NumericField) X,DATASET(Types.NumericField) Y,DATASET(Mat.Types.MUElement) IntW,
      DATASET(Mat.Types.MUElement) IntB, REAL8 LAMBDA=0.00001, REAL8 ALPHA=0.1, UNSIGNED4 MaxIter=100) := MODULE
    SHARED iterRec := RECORD
      DATASET(MUElement) DS; // the child dataset
    END;
    SHARED nSamples := MAX (X, id); //number of samples
    SHARED nFeatures := MAX(X, number); // number of features
    SHARED nOutputs := MAX(Y, number); // number of outputs
    SHARED nLayers := MAX (net, id); // number of layers
    // We are going to run everything local, so move the training data to a single node (i.e. 1).
    SHARED xDist := SORT(DISTRIBUTE(X, 0), id, LOCAL);
    SHARED yDist := SORT(DISTRIBUTE(Y, 0), id, LOCAL);
    // Do the same for the weights and biases.
    SHARED wDist := SORT(DISTRIBUTE(IntW, 0), x, y, LOCAL);
    SHARED bDist := SORT(DISTRIBUTE(IntB, 0), x, y, LOCAL);
    // Sigmoid formula (i.e.  Logistic Sigmoid)
    SHARED REAL8 sigmoid(REAL8 v) := 1/(1+exp(-1*v));
    // Define the Transforms to add and decrease the Numlayers
    // In order to carry weights and biases in one dataset, weights are assigned
    // to 'no' = L and biases to 'no' = L + nLayers.  Addno adds nLayers to
    // the 'no', while Subno returns the biases to the original L.
    SHARED Mat.Types.MUElement Addno (Mat.Types.MUElement l) := TRANSFORM
      SELF.no := l.no+nLayers;
      SELF := l;
    END;
    SHARED Mat.Types.MUElement Subno (Mat.Types.MUElement l) := TRANSFORM
      SELF.no := l.no-nLayers;
      SELF := l;
    END;
    // Encode the weights and biases into one MUElement dataset so that they can
    // both be updated in a loop.
    SHARED initParams := wDist + PROJECT(bDist, Addno(LEFT));

    // FF performs a feed-forward pass on a single datapoint for use by BP.  It is similar to the NNOutput
    // function, except it returns the outputs of each layer instead of only the final output, and it
    // is optimized differently for use by BP
    SHARED FF(DATASET(Mat.Types.MUElement) w, DATASET(Mat.Types.MUElement) b, UNSIGNED di):= FUNCTION
      // Record to use for iteration across layers
      d := xDist(id = di); // Process a single data sample at a time
      // Convert the NumericField dataset to MUElement, which is the final form for A
      A1 := PROJECT(d, TRANSFORM(MUElement, SELF.x := LEFT.number, SELF.y := 1, SELF.no := 1, SELF.value := LEFT.value), LOCAL);
      // Create nLayers - 1 iterRecs to calculate the A's (outputs) for Layers 2 - nLayers
      iterRecs := DATASET(nLayers-1, TRANSFORM(iterRec,
                      SELF.DS := IF(COUNTER = 1, A1, DATASET([], MUElement))));
      // Transform to calculate the A's for layers > 1
      iterRec calc_As(iterRec lr, iterRec rr, UNSIGNED c) := TRANSFORM
        // A[L] = f(A[L-1] * W[L-1] + B[L-1])
        L := c + 1;
        L_1 := c; // L - 1
        // The first time, we get A(1 through L-1) from the right record.  After that, from the left.
        prevA := IF(c = 1, rr.DS, lr.DS);
        // Filter to get just Layer L-1
        aL_1 := prevA(no = L_1);
        // Extract weights and biases for L-1
        wL_1 := Mat.MU.From(w, L_1);
        bL_1 := Mat.MU.From(b, L_1);
        // Multiply the outputs (i.e. A) of the previous layer times each weight
        // WA has the weight times the input value for each weight between L_1 and L
        WA := JOIN(wL_1, aL_1, LEFT.y = RIGHT.x, TRANSFORM(RECORDOF(LEFT),
                        SELF.value := LEFT.value * RIGHT.value, SELF := LEFT), LOCAL);
        // Now sum up the WA's for each x value 
        WA_accum := TABLE(WA, {s := SUM(GROUP, value), n := x}, x, LOCAL);
        // Z is the WA + B before the activation function
        Z := JOIN(WA_accum, bL_1, LEFT.n = RIGHT.x, TRANSFORM(MUElement,
                        SELF.x := LEFT.n, SELF.y := 1, SELF.no := L,
                        SELF.value := LEFT.s + RIGHT.value), LOCAL);
        // Calculate the A for Layer L using the activation function
        aL := PROJECT(Z, TRANSFORM(RECORDOF(LEFT), SELF.value := sigmoid(LEFT.value), SELF := LEFT), LOCAL);
        // Concatenate A(1 through L-1) with A(L) to get the final A (up to this layer)
        A := prevA + aL;
        SELF.DS := A;
      END;
      // Iterate over the layers, accumulating A as a child dataset.
      // Note that RIGHT is only used on the first record.
      outIter := ITERATE(iterRecs, calc_As(LEFT, RIGHT, COUNTER), LOCAL);
      final_A := outIter[COUNT(outIter)].DS;
      RETURN final_A;
    END;//end FF
    // Delta produces the differences required for each output at each layer, starting with the output
    // layer.  The delta for the output layer is computed by comparing A(nLayers) -- the output from
    // the last layer with Y.
    // The deltas for preceding layers uses the delta for the subsequent layer.
    Delta(DATASET(Mat.Types.MUElement) w, DATASET(Mat.Types.MUElement) b, DATASET(Mat.Types.MUElement) A, UNSIGNED di):= FUNCTION
      yVals := yDist(id = di);
      // Siggrad is the derivative (gradient) of the sigmoid function = A * (1-A)
      REAL8 siggrad(REAL8 v) := v*(1-v);
      // Start with the output layer
      A_end := Mat.MU.From(A,nLayers);
      // d(NL, i) = -(Y(i) - A(i)) * f'(Z(L,i)) Note f'(Z(L, i) = siggrad(A(L,i))
      Delta_end := JOIN(yVals, A_end, LEFT.number = RIGHT.x, TRANSFORM(RECORDOF(RIGHT),
                        SELF.value := -(LEFT.value - RIGHT.value) * siggrad(RIGHT.value),
                        SELF := RIGHT), LOCAL);
      Delta_End_no := Mat.MU.To(Delta_end, nLayers);
      // Create nLayers - 1 iterRecs to calculate the d's (deltas) for Layers nLayers - 1 through 2 (reverse order)
      iterRecs := DATASET(nLayers-1, TRANSFORM(iterRec,
                      SELF.DS := IF(COUNTER = 1, Delta_End_no, DATASET([], MUElement))));
      // Transform to calculate the d's for layers from nLayers - 1 through 2
      iterRec calc_Ds(iterRec lr, iterRec rr, UNSIGNED c) := TRANSFORM
        L := nLayers - c;
        prevD := IF(c = 1, rr.DS, lr.DS);
        dL_1 := prevD(no = L+1); // delta[L+1]
        wL := Mat.MU.From(w, L); // weight matrix between layer L and layer L+1 of the neural network
        aL := Mat.MU.From(A, L); // output of layer L
        // d(L, j) = SUM(W(L,j,*) * d(L+1, i)) * f'(Z(L, j)  Note f'(Z(L, i) = siggrad(A(L,i))
        // Sum all the weights coming into each node (x) of layer L+1 * d(x)
        wxd := JOIN(wL, dL_1, LEFT.x = RIGHT.x, TRANSFORM(RECORDOF(LEFT),
                    SELF.value := LEFT.value * RIGHT.value,
                    SELF := LEFT), LOCAL);
        sumWxd := TABLE(wxd, {n := y, tot := SUM(GROUP, value)}, y, LOCAL);
        //sumWts := PROJECT(sumWts0, TRANSFORM(Mat.Types.Element, SELF.x := LEFT.n, SELF.y := 1, SELF.value := LEFT.sumWt), LOCAL);
        siggrad_aL := PROJECT(aL, TRANSFORM(RECORDOF(LEFT), SELF.value := siggrad(LEFT.value),
                              SELF := LEFT), LOCAL);
        Delta_L := JOIN(sumWxd, siggrad_aL, LEFT.n = RIGHT.x, TRANSFORM(MUElement,
                        SELF.x := RIGHT.x,
                        SELF.y := 1,
                        SELF.value := LEFT.tot * RIGHT.value,
                        SELF.no := L), LOCAL);
        SELF.DS := prevD + Delta_L;
      END;
      // Iterate over the layers, accumulating A as a child dataset.
      // Note that RIGHT is only used on the first record.
      outIter := ITERATE(iterRecs, calc_Ds(LEFT, RIGHT, COUNTER), LOCAL);
      final_D := outIter[COUNT(outIter)].DS; 
      RETURN final_D;
    END;//END Delta
    WeightGrad(DATASET(Mat.Types.MUElement) w, DATASET(Mat.Types.MUElement) A, DATASET(Mat.Types.MUElement) Del, UNSIGNED di ):= FUNCTION
      // calculate full gradient term for weights:  Wgrad(L, j, i) = (A(L,j) * delta(L+1, i) + LAMBDA*W(L,j,i))
      // wi_g1 is the first term i.e. A(L,j) * delta(L+1, i)
      // Consolidate all the terms that belong together for the calculation
      // First consolidate w(L, j, i) with A(L, j), one record per weight
      consol := JOIN(w, A, LEFT.y = RIGHT.x AND LEFT.no = RIGHT.no,
                      TRANSFORM({RECORDOF(LEFT), REAL a_val},
                                  SELF.a_val := RIGHT.value,
                                  SELF := LEFT), LOCAL);
      // Now consolidate consol(L, j, i) with delta(L+1, i)
      final_WG := JOIN(consol, Del, LEFT.x = RIGHT.x AND LEFT.no = RIGHT.no - 1,
                      TRANSFORM(Mat.Types.MUElement,
                                  SELF.value := LEFT.a_val * RIGHT.value + LAMBDA * LEFT.value,
                                  SELF := LEFT), LOCAL);
      RETURN final_WG;
    END;//END WeightGrad
    BiasGrad(DATASET(Mat.Types.MUElement) Del ):= FUNCTION
      // calculate full gradient term for biases:  Bgrad(L, i) = d(L+1, i)
      Mat.Types.MUElement calc_grad(Mat.Types.MUElement d) := TRANSFORM
        SELF.no := d.no - 1;
        SELF.x := d.x;
        SELF.y := d.y;
        SELF.value := d.value;
      END;
      final_bg := PROJECT(Del, calc_grad(LEFT));
      RETURN final_bg;
    END;//End BiasGrad
    // Update the weights or bias terms T(L, j, i) = T(L, j, i) - ALPHA * Gradient(L, j, i)
    GradDesUpdate (DATASET(Mat.Types.MUElement) tobeUpdated, DATASET(Mat.Types.MUElement) GradDesTerm ):= FUNCTION
      // Calculate the new term for each pairing of the two terms
      final_updated := JOIN(tobeUpdated, GradDesTerm, LEFT.x = RIGHT.x AND LEFT.y = RIGHT.y AND LEFT.no = RIGHT.no,
                        TRANSFORM(Mat.Types.MUElement,
                          SELF.value := LEFT.value - ALPHA * RIGHT.value,
                          SELF := LEFT), LOCAL);
      RETURN final_updated;
    END;//End GradDesUpdate
    // Main Loop iteration in back propagation algorithm that does the gradient descent and weight and bias updates
    // Note that the input is an encoded combination of weights and biases.
    // Perform MaxIter iterations of Back Propagation
    BPLoop(DATASET(MUElement) Intparams) := FUNCTION
      iterRecs := DATASET(MaxIter, TRANSFORM(iterRec,
                    SELF.DS := IF(COUNTER = 1, Intparams, DATASET([], MUElement))));
      // Perform one iteration of BP
      iterRec iterStep(iterRec lr, iterRec rr, UNSIGNED c) := TRANSFORM
        // Perform BP for a single data sample.  It must be done one sample at a time in order to converge.
        prevInput := IF(c = 1, rr.DS, lr.DS);
        iterRecs2 := DATASET(nSamples, TRANSFORM(iterRec,
                      SELF.DS := IF(COUNTER = 1, prevInput, DATASET([], MUElement))));
        // Transform to calculate the final weights after doing back-propagation for all datapoints
        iterRec dataStep(iterRec lr, iterRec rr, UNSIGNED c) := TRANSFORM
          //w_in : weight matrices
          //b_in : bias matrices
          // Extract the weights and biases from the input
          di := c; // Data index
          prevInp := IF(c = 1, rr.DS, lr.DS);
          w_in := prevInp(no<nLayers); // input weight parameter in MUElement format
          b_in_tmp := prevInp(no>nLayers);
          b_in := PROJECT (b_in_tmp,Subno(LEFT), LOCAL);//input bias parameter in MUElement format
          // Perform a forward pass to get the current outputs from each neuron at each layer.
          A_ffpass :=  FF(w_in,b_in, di);
          //2-apply the back propagation step to update the parameters
          D_delta := DELTA(w_in, b_in, A_ffpass, di);
          Weight_GD := WeightGrad(w_in, A_ffpass,  D_delta, di); // Delta_W -- The full gradient
          Bias_GD := BiasGrad(D_delta); // Delta_B -- The full gradient
          // Apply the gradient to the weights
          NewWeight := GradDesUpdate(w_in, Weight_GD);
          // Apply the gradient to the biases
          NewBias := GradDesUpdate(b_in, Bias_GD);
          // Now encode the new weights and biases together in a dataset for the next round
          NewBias_added := PROJECT (NewBias,Addno(LEFT), LOCAL);
          Updated_Params := NewWeight + NewBias_added;
          // New W + B after one datapoint
          SELF.DS := Updated_Params;
        END; // Data_step
        iterData := ITERATE(iterRecs2, dataStep(LEFT, RIGHT, COUNTER), LOCAL);
        // New W + B after one iteration across all datapoints
        Updated_Params2 := iterData[COUNT(iterData)].DS;
        SELF.DS := Updated_Params2;
      END; // END iterStep
      iterUpdated := ITERATE(iterRecs, iterStep(LEFT, RIGHT, COUNTER), LOCAL);
      Final_Updated_Params := iterUpdated[COUNT(iterUpdated)].DS;
      RETURN Final_Updated_Params;
    END; // END BPLoop
    NNparams := BPLoop(initParams);// NNparams is in Mat.Types.MUElement format (encoded weights and biases)
    //convert to a model in NumericField format
    nnparam1 := Mat.MU.From(NNparams,1);
    nnparam1_mat_no := Mat.MU.TO(nnparam1,1);
    Mu_convert(DATASET(Mat.Types.MUElement) inputMU, INTEGER coun) := FUNCTION
      L := IF(coun < nLayers-1, coun+1, coun+2);
      nnparamL := Mat.MU.From(NNparams,L);
      nnparamL_mat_no := Mat.MU.TO(nnparamL,L);
      RETURN inputMU+nnparamL_mat_no;
    END;
    NNparams_MUE := LOOP(nnparam1_mat_no, 2*nLayers-3, Mu_convert(ROWS(LEFT),COUNTER));
    ML.AppendID(NNparams_MUE, id, NNparams_MUE_id);
    ML.ToField (NNparams_MUE_id, NNparams_MUE_out, id, 'x,y,value,no');
    EXPORT Mod := NNparams_MUE_out;//mod is in NumericField format
  END; // END BP
  /**
    * This function is used to train the network. It performs the Back-Propagation (BP) algorithm
    * and returns a model containing the trained weights and biases for the network.
    * It may take a long time to complete, depending on the size of the dataset, the complexity (shape)
    * of the network, and the parameters supplied.
    * Note the meaning of the parameters ALPHA and LAMBDA described below.  These names are based on the Stanford
    * tutorial and their meaning can vary widely across implementations.
    *
    * @param Indep The independent data in DATASET(NumericField) format
    * @param Dep The dependent data in DATASET(NumericField) format
    * @param IntW The initial weights for the network, typically obtained from a call to IntWeights
    * @param IntB The initial bias values for the network, typically obtained from a call to IntBias
    * @param LAMBDA Regularization Parameter between 0 and 1 that penalizes complexity of the solution.
    *               A small value (e.g. 10^-5 -- the default) is typically used.  This parameter is used to reduce
    *               overfitting, and can improve the out-of-training-sample accuracy when adjusted properly
    * @param ALPHA Learning-rate.  Parameter between 0 and 1 that determines the step size for back-propagation.
    *              Larger values will train faster, but may overstep the optimal solution.  Lower values
    *              should be used for problems with very complex decision surfaces.  Typically values between
    *              .01 and .5 are reasonable.  The default value of .1 is a good starting point.
    * @param MaxIter This is the number of Back-Propagation loops to execute.  The current implementation
    *               does not provide for early stopping, so care must be taken with specification of this
    *               value.  If it is too large, it may run for a very long time.  If it is too small, it
    *               can grossly underfit the data, yielding worthless results.  If it is only slightly too
    *               small, it can enhance generalization, which can cause accidental benefits (which should
    *               not be depended on).  The optimum level for this parameter varies based on the size of
    *               the training set since the number of weight adjustment steps is numberTrainingRecs * 
    *               MaxIter.
    * @return The learned model
    *
    */
  EXPORT NNLearn(DATASET(Types.NumericField) Indep, DATASET(Types.NumericField) Dep,DATASET(Mat.Types.MUElement) IntW, DATASET(Mat.Types.MUElement) Intb, REAL8 LAMBDA=0.00001, REAL8 ALPHA=0.1, UNSIGNED4 MaxIter=100) := BP(Indep,Dep, IntW,  Intb, LAMBDA,  ALPHA,  MaxIter).mod;
  /**
    * This function applies the feed forward pass to the input dataset (Indep) based on the
    * input neural network model (Learntmod).
    *
    * @param Indep The independent data
    * @param Learntmod The model as returned from NNLearn
    * @return Predicted numeric values in DATASET(NumericField format)
    */
  EXPORT DATASET(Types.NumericField) NNOutput(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) Learntmod) :=FUNCTION
    //used fucntion
    PBblas_v0.Types.value_t sigmoid(PBblas_v0.Types.value_t v, PBblas_v0.Types.dimension_t r, PBblas_v0.Types.dimension_t c) := 1/(1+exp(-1*v));
    dt := Types.ToMatrix (Indep);
    dTmp := dt;
    d := Mat.Trans(dTmp); //in the entire of the calculations we work with the d matrix that each sample is presented in one column
    m := MAX (d, d.y); //number of samples
    m_1 := 1/m;
    sizeRec := RECORD
      PBblas_v0.Types.dimension_t m_rows;
      PBblas_v0.Types.dimension_t m_cols;
      PBblas_v0.Types.dimension_t f_b_rows;
      PBblas_v0.Types.dimension_t f_b_cols;
    END;
   //Map for Matrix d.
    dstats := Mat.Has(d).Stats;
    d_n := dstats.XMax;
    d_m := dstats.YMax;
    NL := MAX(net,id);
    iterations := NL-2;
    output_num := net(id=NL)[1].value;
    derivemap := PBblas_v0.AutoBVMap(d_n, d_m,0,0);
    sizeTable := DATASET([{derivemap.matrix_rows,derivemap.matrix_cols,derivemap.part_rows(1),derivemap.part_cols(1)}], sizeRec);
    //Create block matrix d
    dmap := PBblas_v0.Matrix_Map(sizeTable[1].m_rows,sizeTable[1].m_cols,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);
    ddist := DMAT.Converted.FromElement(d,dmap);
    //Extract Weights and Bias
    W_mat := ExtractWeights (Learntmod);
    B_mat := ExtractBias (Learntmod);
    //create w1 partition block matrix
    w1_mat := Mat.MU.From(W_mat,1);
    w1_mat_x := Mat.Has(w1_mat).Stats.Xmax;
    w1_mat_y := Mat.Has(w1_mat).Stats.Ymax;
    w1map := PBblas_v0.Matrix_Map(w1_mat_x, w1_mat_y, sizeTable[1].f_b_rows, sizeTable[1].f_b_rows);
    w1dist := DMAT.Converted.FromElement(w1_mat,w1map);
    //repeat b1 vector in m columns and the create the partition block matrix
    b1_mat := Mat.MU.From(B_mat,1);
    b1_mat_x := Mat.Has(b1_mat).Stats.Xmax;
    b1_mat_rep := Mat.Repmat(b1_mat, 1, m); // Bias vector is repeated in m columns to make the future calculations easier
    b1map := PBblas_v0.Matrix_Map(b1_mat_x, m, sizeTable[1].f_b_rows, sizeTable[1].f_b_cols);
    b1dist := DMAT.Converted.FromElement(b1_mat_rep,b1map);
    //calculate a2 (output from layer 2)
    //z2 = w1*X+b1;
    z2 := PBblas_v0.PB_dgemm(FALSE, FALSE,1.0,w1map, w1dist, dmap, ddist, b1map, b1dist, 1.0);
    //a2 = sigmoid (z2);
    a2 := PBblas_v0.Apply2Elements(b1map, z2, sigmoid);
    FF_Step(DATASET(Layout_Part) A, INTEGER coun) := FUNCTION
      L := coun + 1;
      aL := A; //output of layer L
      aL_x := net(id=L)[1].value;;
      aLmap := PBblas_v0.Matrix_Map(aL_x,m,sizeTable[1].f_b_rows,sizeTable[1].f_b_cols);
      //creat wL partion block matrix
      wL_mat := Mat.MU.From(W_mat,L);
      wL_mat_x := Mat.Has(wL_mat).Stats.Xmax;
      wL_mat_y := Mat.Has(wL_mat).Stats.Ymax;
      wLmap := PBblas_v0.Matrix_Map(wL_mat_x, wL_mat_y, sizeTable[1].f_b_rows, sizeTable[1].f_b_rows);
      wLdist := DMAT.Converted.FromElement(wL_mat,wLmap);
      //repeat b1 vector in m columsn and the creat the partion block matrix
      bL_mat := Mat.MU.From(B_mat,L);
      bL_mat_x := Mat.Has(bL_mat).Stats.Xmax;
      bL_mat_rep := Mat.Repmat(bL_mat, 1, m); // Bias vector is repeated in m columns to make the future calculations easier
      bLmap := PBblas_v0.Matrix_Map(bL_mat_x, m, sizeTable[1].f_b_rows, sizeTable[1].f_b_cols);
      bLdist := DMAT.Converted.FromElement(bL_mat_rep,bLmap);
      //calculate a(L+1) (output from layer L)
      //z(L+1) = wL*X+bL;
      zL_1 := PBblas_v0.PB_dgemm(FALSE, FALSE,1.0, wLmap, wLdist, aLmap, aL, bLmap, bLdist, 1.0);
      //aL_1 = sigmoid (zL_1);
      aL_1 := PBblas_v0.Apply2Elements(bLmap, zL_1, sigmoid);
      RETURN aL_1;
    END;
    final_A := LOOP(a2, COUNTER <= iterations, FF_Step(ROWS(LEFT),COUNTER));
    final_A_mat := DMat.Converted.FromPart2Elm(final_A);
    Types.NumericField tr(Mat.Types.Element le) := TRANSFORM
      SELF.id := le.y;
      SELF.number := le.x;
      SELF.value := le.value;
    END;
    RETURN PROJECT (Final_A_mat, tr(LEFT));
  END;// END NNOutput
  /**
    * NNClassify performs a binary classification.
    *
    * Classifies points as belonging to one of two classes (0 or 1)
    * Performs NNOutput and maps values > .5 ==> 1 and others to 0.
    * The Dependent training data must use values of 0 and 1 for the two classes.
    *
    * @param Indep The independent data
    * @param Learntmod The model as returned from NNLearn
    * @return Predicted class values in DATASET(l_result) format.  'Value' contains
    *         the class number (0 or 1) and 'conf' contains the strength of the prediction
    *         0 <= conf <= 1.
    *
    **/
  EXPORT NNClassify(DATASET(Types.NumericField) Indep,DATASET(Types.NumericField) Learntmod) := FUNCTION
    Dist := NNOutput(Indep, Learntmod);
    classified := PROJECT(Dist, TRANSFORM(Types.l_result, SELF.number := LEFT.number, 
                      SELF.value := IF(LEFT.value >= .5, 1, 0),
                      SELF.conf := ABS(2 * (LEFT.value - .5)), SELF := LEFT));
    RETURN classified;
   END; // END NNClassify
END;//END NeuralNetworks