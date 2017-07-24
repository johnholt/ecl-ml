IMPORT ML;
IMPORT PBblas_v0 as PBblas_v0;
IMPORT ML.DMat as DMat;
IMPORT PBblas_v0.MU AS MU;
IMPORT PBblas_v0.Types AS Types;

Part := Types.Layout_Part;
IMatrix_Map := PBblas_v0.IMatrix_Map;
Side := Types.Side;
Triangle := Types.Triangle;
Diagonal := Types.Diagonal;

EXPORT QR(IMatrix_map d_map, DATASET(Part) D) := MODULE
  SHARED qr_comp := ENUM ( Q = 1, R = 2 );
  EXPORT QR() := FUNCTION
    dT_map := DMat.Trans.TranMap(d_map);
    dTd_map := PBblas_v0.Matrix_map(dT_map.matrix_rows, d_map.matrix_cols, dT_map.part_rows(1), d_map.part_cols(1));
    DtD := PBblas_v0.PB_dgemm(TRUE, FALSE, 1.0, d_map, D, d_map, D, dTd_map);
    R := DMat.Decomp.Cholesky(dTd_map, DtD, PBblas_v0.Types.Triangle.Upper);
    r_map := dTd_map;
    Ri := PBblas_v0.PB_dtrsm(Side.Ax, Triangle.Upper, FALSE,Diagonal.NotUnitTri, 1.0, r_map, R, r_map, DMat.Identity(r_map));
    q_map := PBblas_v0.Matrix_Map(d_map.matrix_rows, r_map.matrix_cols, d_map.part_rows(1), r_map.part_cols(1));
    Q := DMat.Mul(d_map, D, r_map, Ri, q_map);
    RETURN Mu.To(R, qr_comp.R)+Mu.To(Q, qr_comp.Q);
  END;

  EXPORT QComp := MU.From(QR(), qr_comp.Q);
  EXPORT RComp := MU.From(QR(), qr_comp.R);
END;