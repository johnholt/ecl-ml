// Pure dense matrix substraction based upon PB-BLAS
IMPORT PBblas_v0;
IMPORT PBblas_v0.Types;
Part := Types.Layout_Part;
IMatrix_Map := PBblas_v0.IMatrix_Map;
EXPORT DATASET(Part) Sub(IMatrix_Map m_map, DATASET(Part) minuend,
                         IMatrix_Map s_map, DATASET(Part) subtrahend) := FUNCTION
  RETURN PBblas_v0.PB_daxpy(-1.0, subtrahend, minuend);
END;
