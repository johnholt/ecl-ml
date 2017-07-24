//Pure dense matrix scalar multiply using PB BLAS
IMPORT PBblas_v0;
IMPORT PBblas_v0.Types;
Part := Types.Layout_Part;
t_value := Types.value_t;
IMatrix_Map := PBblas_v0.IMatrix_Map;

EXPORT DATASET(Part) Scale(IMatrix_Map a_map, t_value alpha,
                           DATASET(Part) a) := FUNCTION
  RETURN PBblas_v0.PB_dscal(alpha, a);
END;