//Calculate a set of partition schemes that will be efficient for
//the provide operations and matrix dimensions.
//
IMPORT PBblas;
IMPORT PBblas.Types;
Desc := Types.Layout_Matrix_Desc;
Oper := Types.layout_Operation;
Schm := Types.Layout_Scheme;
op_multiply := Types.Operation.Multiply;
op_single := Types.Operation.Single;
op_left_solve := Types.Operation.LeftSolve;
op_right_solve := Types.Operation.RightSolve;
max_per_block := 1000000;   // maximum cells per block
min_full := 100;            // minimum full block rows or columns

EXPORT Scheme(DATASET(Desc) mats, DATASET(Oper) ops) := FUNCTION
  // Rationalize dims -- patch squares
  Desc patchSquare(Desc d) := TRANSFORM
    Types.dimension_t max_dim := MAX(d.matrix_rows, d.matrix_cols);
    SELF.matrix_rows := IF(d.isSquare, max_dim, d.matrix_rows);
    SELF.matrix_cols := IF(d.isSquare, max_dim, d.matrix_cols);
    SELF := d;
  END;
  patched := PROJECT(mats, patchSquare(LEFT));
  // Rationalize dims -- get relationships
  Dim_Ex := RECORD
    Types.nominal_t l_source;
    Types.nominal_t r_source;
    Types.nominal_t eq;
    Types.dimension_t common_dim;
    BOOLEAN l_isRow;
    BOOLEAN r_isCol;
    BOOLEAN l_square;
    BOOLEAN r_square;
    BOOLEAN l_trans;
    BOOLEAN r_trans;
  END;
  Op_Ex := RECORD(Oper)
    Types.nominal_t eq;
  END;
  num_chks(Types.Operation op) := CASE(op,
                                      op_multiply   => 3,
                                      op_single     => 0,
                                      1);
  Dim_Ex check1(Op_Ex op, UNSIGNED c) := TRANSFORM
    SELF.l_source := CASE(c,  1   => op.nominal_A,
                              2   => op.nominal_A,
                              op.nominal_B);
    SELF.r_source := IF(c=1, op.nominal_B, op.nominal_C);
    SELF.l_isRow := (c=1 AND op.op=op_right_solve AND NOT op.trans_A)
                 OR (c=1 AND op.op=op_left_solve AND op.trans_A)
                 OR (c=1 AND op.op=op_multiply AND op.trans_A)
                 OR (c=2 AND NOT op.trans_A)
                 OR (c=3 AND op.trans_B);
    SELF.r_isCol := (c=1 AND op.op=op_left_solve)
                 OR (c=1 AND op.op=op_multiply AND op.trans_B)
                 OR c=3;
    SELF.l_trans := IF(c=3, op.trans_B, op.trans_A);
    SELF.r_trans := IF(c=1, op.trans_B, FALSE);
    SELF.eq := op.eq;
    SELF := [];
  END;
  o_ex := PROJECT(ops, TRANSFORM(Op_Ex, SELF.eq:=COUNTER,SELF:=LEFT));
  op_checks := NORMALIZE(o_ex, num_chks(LEFT.op), check1(LEFT, COUNTER));
  // Rationalize dims -- get specified dims
  Dim_Ex get_dims(Dim_Ex ck, Desc mat_d, BOOLEAN lft) := TRANSFORM
    dim := MAP(lft AND ck.l_isRow           => mat_d.matrix_rows,
               lft                          => mat_d.matrix_cols,
               ck.r_isCol                   => mat_d.matrix_cols,
               mat_d.matrix_rows);
    SELF.common_dim := MAX(dim, ck.common_dim);
    SELF.l_square := IF(lft, mat_d.isSquare, ck.l_square);
    SELF.r_square := IF(lft, ck.r_square, mat_d.isSquare);
    SELF := ck;
  END;
  with_left := JOIN(op_checks, patched,
                   LEFT.l_source=RIGHT.matrix_nominal,
                   get_dims(LEFT, RIGHT, TRUE), LOOKUP);
  with_both := JOIN(with_left, patched,
                   LEFT.r_source=RIGHT.matrix_nominal,
                   get_dims(LEFT, RIGHT, FALSE), LOOKUP);
  Dim_Ex gen_alt(Dim_Ex ck, BOOLEAN lft) := TRANSFORM
    SELF.l_isRow := IF(lft, NOT ck.l_isRow, ck.l_isRow);
    SELF.r_isCol := IF(lft, ck.r_isCol, NOT ck.r_isCol);
    SELF := ck;
  END;
  left_sq := PROJECT(with_both(l_square), gen_alt(LEFT, TRUE));
  right_sq := PROJECT(with_both(r_square), gen_alt(LEFT, FALSE));
  all_cases := with_both + left_sq + right_sq;
  // Rationalize dims -- get max values and apply to extract
  //descriptions.  The max number of iterations required to propagate is
  //the smaller of the number of matrices or the number of operations,
  //less 1.
  Work_Max := RECORD
    Types.nominal_t nominal;
    Types.dimension_t dimension;
    BOOLEAN isRow;
  END;
  Work_Max ext_dims(Dim_Ex ck, UNSIGNED c) := TRANSFORM
    SELF.nominal := IF(c=1, ck.l_source, ck.r_source);
    SELF.dimension := ck.common_dim;
    SELF.isRow := IF(c=1, ck.l_isRow, ~ck.r_isCol);
  END;
  Max_Tab := RECORD
    Types.nominal_t nominal;
    Types.dimension_t mx_d;
    BOOLEAN isRow;
  END;
  Dim_Ex apply_max(Dim_Ex ck, Max_Tab d) := TRANSFORM
    SELF.common_dim := MAX(ck.common_dim, d.mx_d);
    SELF := ck;
  END;
  DATASET(Dim_Ex) prop_max(DATASET(Dim_Ex) chks) := FUNCTION
    w_dim := NORMALIZE(chks, 2, ext_dims(LEFT, COUNTER));
    max_dim := PROJECT(TABLE(w_dim,
                    {nominal, mx_d:=MAX(GROUP,dimension), isRow},
                    nominal, isRow, UNSORTED, FEW), Max_Tab);
    dims_l_set := JOIN(all_cases, max_dim,
                    LEFT.l_source=RIGHT.nominal
                    AND LEFT.l_isRow=RIGHT.isRow,
                    apply_max(LEFT, RIGHT), LOOKUP);
    dims_both := JOIN(dims_l_set, max_dim,
                    LEFT.r_source=RIGHT.nominal
                    AND LEFT.r_isCol<>RIGHT.isRow,
                    apply_max(LEFT, RIGHT), LOOKUP);
    RETURN dims_both;
  END;
  //
  prop_iter := MIN(COUNT(ops), COUNT(mats)) - 1;
  r_cases := LOOP(all_cases, prop_iter, prop_max(ROWS(LEFT)));
  // Rationalize dims -- Apply to matrix descriptions and pick up any
  // descriptions that have only single operations
  Track := RECORD
    Types.nominal_t id;
  END;
  Desc_ex := RECORD(Desc)
    DATASET(Track) eqns;
  END;
  Desc_ex map_dim(Dim_Ex ck, UNSIGNED c) := TRANSFORM
    SELF.matrix_nominal := IF(c=1, ck.l_source, ck.r_source);
    SELF.matrix_rows := IF((c=1 AND ck.l_isRow)
                          OR (c=2 AND ~ck.r_isCol)
                          OR (c=1 AND ck.l_square)
                          OR (c=2 AND ck.r_square), ck.common_dim, 0);
    SELF.matrix_cols := IF((c=1 AND ~ck.l_isRow)
                          OR (c=2 AND ck.r_isCol)
                          OR (c=1 AND ck.l_square)
                          OR (c=2 AND ck.r_square), ck.common_dim, 0);
    SELF.isSquare := IF(c=1, ck.l_square, ck.r_square);
    SELF.eqns := ROW({ck.eq}, Track);
    SELF := ck;
  END;
  ex_dims := NORMALIZE(r_cases, 2, map_dim(LEFT, COUNTER));
  Desc_ex getSingles(Desc base, Op_ex single) := TRANSFORM
    SELF.eqns := IF(single.eq>0, DATASET([{single.eq}], Track));
    SELF := base;
  END;
  single_ops := DEDUP(SORT(o_ex(op=op_single), nominal_A), nominal_A);
  original_dims := JOIN(patched, single_ops,
                        LEFT.matrix_nominal=RIGHT.nominal_A,
                        getSingles(LEFT,RIGHT), LEFT OUTER, LOOKUP);
  sr_dims := SORT(ex_dims+original_dims, matrix_nominal);
  Desc_ex roll_dims(Desc_ex accum, Desc_ex incr) := TRANSFORM
    accum_eqns := SORTED(accum.eqns);
    incr_eqns := SORTED(incr.eqns);
    SELF.matrix_nominal := accum.matrix_nominal;
    SELF.matrix_rows := MAX(accum.matrix_rows, incr.matrix_rows);
    SELF.matrix_cols := MAX(accum.matrix_cols, incr.matrix_cols);
    SELF.isSquare := accum.isSquare OR incr.isSquare;
    SELF.eqns := MERGE(accum_eqns, incr_eqns, SORTED(id), DEDUP);
  END;
  r_desc := ROLLUP(sr_dims, roll_dims(LEFT,RIGHT), matrix_nominal);
  // The partition sizes are constrained by the total number of entries.
  //Find constraining case and propagate constraint to all matrix
  //descriptions.  Worst case is as before, smaller of equation
  //or matrix count less 1.
  Check_Eqn := RECORD
    UNSIGNED8 matrix_cells;
    DATASET(Track) noms;
    Types.nominal_t eq;
  END;
  Check_Mat := RECORD
    UNSIGNED8 matrix_cells;
    DATASET(Track) eqns;
    Types.nominal_t matrix_nominal;
  END;
  Check_Mat cvt_desc(Desc_ex d) := TRANSFORM
    SELF.matrix_cells := d.matrix_rows * d.matrix_cols;
    SELF.eqns := d.eqns;
    SELF.matrix_nominal := d.matrix_nominal;
  END;
  Check_Eqn extract_eqn(Check_Mat d, Track t) := TRANSFORM
    SELF.eq := t.id;
    SELF.noms := ROW({d.matrix_nominal}, Track);
    SELF.matrix_cells := d.matrix_cells;
  END;
  Check_Mat extract_mat(Check_Eqn e, Track t) := TRANSFORM
    SELF.matrix_nominal := t.id;
    SELF.eqns := ROW({e.eq}, Track);
    SELF.matrix_cells := e.matrix_cells;
  END;
  Check_Eqn roll_Eqn(Check_Eqn base, Check_Eqn incr) := TRANSFORM
    base_noms := SORTED(base.noms);
    incr_noms := SORTED(incr.noms);
    SELF.matrix_cells := MAX(base.matrix_cells, incr.matrix_Cells);
    SELF.noms := MERGE(base_noms, incr_noms, SORTED(id), DEDUP);
    SELF.eq := base.eq;
  END;
  Check_Mat roll_Mat(Check_Mat base, Check_Mat incr) := TRANSFORM
    base_eqns := SORTED(base.eqns);
    incr_eqns := SORTED(incr.eqns);
    SELF.matrix_cells := MAX(base.matrix_cells, incr.matrix_cells);
    SELF.eqns := MERGE(base_eqns, incr_eqns, SORTED(id), DEDUP);
    SELF.matrix_nominal := base.matrix_nominal;
  END;
  DATASET(Check_Mat) prop_constraint(DATASET(Check_Mat) cm) := FUNCTION
    e0 := NORMALIZE(cm, LEFT.eqns, extract_eqn(LEFT, RIGHT));
    e1 := SORT(e0, eq);
    e_constraint := ROLLUP(e1, roll_Eqn(LEFT, RIGHT), eq)
                :ONWARNING(1031, IGNORE);
    m0 := NORMALIZE(e_constraint, LEFT.noms, extract_mat(LEFT,RIGHT));
    m1 := SORT(m0, matrix_nominal);
    m_constraint := ROLLUP(m1, roll_Mat(LEFT,RIGHT), matrix_nominal)
                :ONWARNING(1031, IGNORE);
    RETURN m_constraint;
  END;
  r_check := PROJECT(r_desc, cvt_desc(LEFT));
  constraints := LOOP(r_check, prop_iter, prop_constraint(ROWS(LEFT)));
  // Determine maps.  Use the constraint matrix cells to determine
  //the size of the system (partitions) to overlay.  The system of
  //partitions is always square so AB and BA are both valid.
  Schm setScheme(Desc_ex d, Check_Mat cm) := TRANSFORM
    min_nodes := 1 + ((cm.matrix_cells-1) DIV max_per_block);
    sys_dim := 1 + SQRT(MAX(CLUSTERSIZE,min_nodes)-1);
    SELF.block_rows := MAX(((d.matrix_rows-1) DIV sys_dim)+1, min_full);
    SELF.block_cols := MAX(((d.matrix_cols-1) DIV sys_dim)+1, min_full);
    SELF := d;
  END;
  rslt := JOIN(r_desc, constraints,
               LEFT.matrix_nominal=RIGHT.matrix_nominal,
               setScheme(LEFT,RIGHT), LOOKUP);
  RETURN rslt;
END;