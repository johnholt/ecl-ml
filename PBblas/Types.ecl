// Types for the Parellel Block Basic Linear Algebra Sub-programs support
// WARNING: attributes marked with WARNING can not be changed without making
//corresponding changes to the C++ attributes.
EXPORT Types := MODULE
  EXPORT dimension_t  := UNSIGNED4;     // WARNING: type used in C++ attributes
  EXPORT partition_t  := UNSIGNED2;
  EXPORT node_t       := UNSIGNED2;
  EXPORT value_t      := REAL8;         // Warning: type used in C++ attribute
  EXPORT matrix_t     := SET OF REAL8;  // Warning: type used in C++ attribute
  EXPORT Triangle     := ENUM(UNSIGNED1, Upper=1, Lower=2); //Warning
  EXPORT Diagonal     := ENUM(UNSIGNED1, UnitTri=1, NotUnitTri=2);  //Warning
  EXPORT Side         := ENUM(UNSIGNED1, Ax=1, xA=2);  //Warning
  EXPORT t_mu_no      := UNSIGNED2; //Allow up to 64k matrices in one universe
  EXPORT nominal_t    := UNSIGNED2;

  // Sparse
  EXPORT Layout_Cell  := RECORD   // WARNING:  Do not change without MakeR8Set
    dimension_t     x;    // 1 based index position
    dimension_t     y;    // 1 based index position
    value_t         v;
  END;
  // Dense
  EXPORT Layout_Part  := RECORD
    node_t          node_id;
    partition_t     partition_id;
    dimension_t     block_row;
    dimension_t     block_col;
    dimension_t     first_row;
    dimension_t     part_rows;
    dimension_t     first_col;
    dimension_t     part_cols;
    matrix_t        mat_part;
  END;
  // Extended for routing
  EXPORT Layout_Target := RECORD
    partition_t     t_part_id;
    node_t          t_node_id;
    dimension_t     t_block_row;
    dimension_t     t_block_col;
    dimension_t     t_term;
    Layout_Part;
  END;
  //Matrix Universe
  EXPORT MUElement := RECORD(Layout_Part)
    t_mu_no no; // The number of the matrix within the universe
  END;
  // Matrix Partitioning scheme
  EXPORT Layout_Matrix_Desc := RECORD
    dimension_t matrix_rows;
    dimension_t matrix_cols;
    nominal_t matrix_nominal;
    BOOLEAN isSquare;
  END;
  EXPORT Operation := ENUM(Multiply, LeftSolve, RightSolve, Single);
  EXPORT Layout_Operation := RECORD
    nominal_t nominal_A;
    nominal_t nominal_B;
    nominal_t nominal_C;
    Operation op;
    BOOLEAN trans_A;
    BOOLEAN trans_B;
  END;
  EXPORT Layout_Operation makeLeftSolve(BOOLEAN trans_A, nominal_t nom_A,
                                        nominal_t nom_B) := TRANSFORM
    SELF.nominal_A := nom_A;
    SELF.nominal_B := nom_B;
    SELF.op := Operation.LeftSolve;
    SELF.trans_A := trans_A;
    SELF := [];
  END;
  EXPORT Layout_Operation makeRightSolve(BOOLEAN trans_A, nominal_t nom_a,
                                        nominal_t nom_B) := TRANSFORM
    SELF.nominal_A := nom_A;
    SELF.nominal_B := nom_B;
    SELF.op := Operation.RightSolve;
    SELF.trans_A := trans_A;
    SELF := [];
  END;
  EXPORT Layout_Operation makeSingle(nominal_t nom_a) := TRANSFORM
    SELF.nominal_A := nom_A;
    SELF.op := Operation.Single;
    SELF := [];
  END;
  EXPORT Layout_Operation makeMultiply(BOOLEAN trans_A, nominal_t nom_A,
                                       BOOLEAN trans_B, nominal_t nom_B,
                                       UNSIGNED2 nom_C) := TRANSFORM
    SELF.nominal_A := nom_A;
    SELF.nominal_B := nom_B;
    SELF.nominal_C := nom_C;
    SELF.op := Operation.Multiply;
    SELF.trans_A := trans_A;
    SELF.trans_B := trans_B;
  END;
  EXPORT Layout_Scheme := RECORD
    dimension_t matrix_rows;
    dimension_t matrix_cols;
    dimension_t block_rows; // rows in full block/partition
    dimension_t block_cols; // cols in full block/partition
    nominal_t matrix_nominal;
  END;
END;