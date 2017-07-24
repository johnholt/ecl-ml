//Pure dense matrix multiply based upon PB BLAS multiply
IMPORT PBblas_v0;
IMPORT PBblas_v0.Types;
Part := Types.Layout_Part;
IMatrix_Map := PBblas_v0.IMatrix_Map;
EXPORT DATASET(Part) Mul(IMatrix_Map f1_map, DATASET(Part) f1,
                         IMatrix_Map f2_map, DATASET(Part) f2,
                         IMatrix_Map result_map) := FUNCTION
  RETURN PBblas_v0.PB_dgemm(FALSE, FALSE, 1.0, f1_map, f1, f2_map, f2, result_map);
END;