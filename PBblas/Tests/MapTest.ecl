//This test can be used to determine a suggested size for matrix partitions
//Only the first two params of AutoBVMap are needed for this. (NumRows,NumCols)
//That last two params can be include if you want to change the maximum 
//number of rows/cols per partition. (NumRows,NumCols,,,MaxRows,MaxCols)
//Can be used to determine inputs for partition sizes for that use the AutoMap function
//To speed results by skipping the Auto phase during code execution. (i.e. ML.Classify.Logistic input)
//Keep in mind that this is only for an individual matrix and for matrix operations
//all matrices and their partitions must be compatible.

IMPORT PBblas;
IMPORT PBblas.Types;

mXmap1 := PBblas.AutoBVMap(100000,29);
mXmap2 := PBblas.AutoBVMap(100000,29,,,5000,200);
mXmap3 := PBblas.AutoBVMap(1000, 200000);
mXmap4 := PBblas.AutoBVMap(1000, 200000,,,200,5000);

sizeRec := RECORD
  PBblas.Types.dimension_t matrix_rows;
  PBblas.Types.dimension_t matrix_cols;
  PBblas.Types.dimension_t full_block_rows;
  PBblas.Types.dimension_t full_block_cols;
  PBblas.Types.dimension_t row_blocks;
  PBblas.Types.dimension_t col_blocks;
END;
sizeRec cvt_map(PBblas.IMatrix_Map xm) := TRANSFORM
  SELF.matrix_rows := xm.matrix_rows;
  SELF.matrix_cols := xm.matrix_cols;
  SELF.full_block_rows := xm.block_rows;
  SELF.full_block_cols := xm.block_cols;
  SELF.row_blocks := xm.row_blocks;
  SELF.col_blocks := xm.col_blocks;
END;

sizeTable := DATASET([cvt_map(mXmap1), cvt_map(mXmap2),
                      cvt_map(mXmap3), cvt_map(mXmap4)]);

OUTPUT(sizeTable, NAMED('BV_Partition_schemes'));

Types.Layout_Matrix_Desc makeMat(UNSIGNED r, UNSIGNED c, UNSIGNED n,
                                 BOOLEAN isQ) := TRANSFORM
  SELF.matrix_rows := r;
  SELF.matrix_cols := c;
  SELF.matrix_nominal := n;
  SELF.isSquare := isQ;
END;
// Matrix operations
// AB+C, D, xE=C
// FG+H, Hx=J, K'K + H
// A=1, B=2, C=3, D=4, E=5,
// F=6, G=7, H=8, J=9, K=10
//
//Test description:
//(A,B,C,E); D; (F,G,H,J,K) are independent of each other.
//
// A - test coercion to max dimensions
// B - not changed
// C - test coercion to max dimensions
// D - test stand alone matrix definition.  A vector of blocks.
// E - test unspecified matrix, rows and columns determined by C
// F - no change
// G - test indirect force
// H - test force to square and indirect
// J - left alone
// K - test indirect force 
m_desc := DATASET([makeMat(100,10,1,FALSE),
                   makeMat(10,200,2,FALSE),
                   makeMat(100,100,3,FALSE),
                   makeMat(120000,5,4,FALSE),
                   makeMat(0,0,5,TRUE),
                   makeMat(2000,20000,6,FALSE),
                   makeMat(20000,1000, 7,FALSE),
                   makeMat(0,0,8,FALSE),
                   makeMat(2000,20,9,FALSE),
                   makeMat(8,1000,10,FALSE)]);
m_ops := DATASET([Types.makeMultiply(FALSE,1,FALSE,2,3),
                  Types.makeSingle(4),
                  Types.makeleftSolve(TRUE,5,3),
                  Types.makeMultiply(FALSE,6,FALSE,7,8),
                  Types.makeRightSolve(FALSE,8,9),
                  Types.makeMultiply(TRUE,10,FALSE,10,8)]);
schemes := PBblas.Scheme(m_desc, m_ops);
OUTPUT(schemes, NAMED('MM_Partiton_Schemes'));
