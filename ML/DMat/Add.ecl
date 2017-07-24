//Pure dense matrix add based upon PB-BLAS
IMPORT PBblas_v0;
IMPORT PBblas_v0.Types;
Part := Types.Layout_Part;
IMatrix_Map := PBblas_v0.IMatrix_Map;
EXPORT DATASET(Part) Add(IMatrix_Map a1_map, DATASET(Part) addend1,
                         IMatrix_Map a2_map, DATASET(Part) addend2) := FUNCTION
  RETURN PBblas_v0.PB_daxpy(1.0, addend1, addend2);
END;
