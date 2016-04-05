IMPORT $.Types AS Types;
IMPORT Std.System.ThorLib;
Stats_Rec := Types.Model_Collection_Stats;
/**
 * Collection information.  Includes mapping nominals to frequency
 * based ordinals for more compact representations.
 * @param models    the model identifiers used for this run.
 * @param docs      the mapped documents for this run
 */

EXPORT Collection_Stats(DATASET(Types.Model_Identifier) models,
                        DATASET(Types.Doc_Mapped) docs) := MODULE
  //assign docs to models
  SHARED Work_Doc := RECORD(Types.Doc_Mapped)
    Types.t_model_id model;
  END;
  Work_Doc amdl(Types.Doc_Mapped doc, Types.Model_Identifier mdl) := TRANSFORM
    SELF.model := mdl.model;
    SELF := doc;
  END;
  SHARED assigned := JOIN(docs, models, RIGHT.model IN LEFT.models,
                   amdl(LEFT, RIGHT), ALL); // model is a small record set
  // Extract the terms for counting
  SHARED Work_Term := RECORD
    Types.t_model_id model;
    Types.t_record_id rid;
    Types.t_nominal nominal;
    UNSIGNED8 freq;
  END;
  Work_Term ext_term(Work_Doc doc, Types.TermFreq term) := TRANSFORM
    SELF.rid := doc.rid;
    SELF.model := doc.model;
    SELF.nominal := term.nominal;
    SELF.freq := term.v;
  END;
  t_list := NORMALIZE(assigned, LEFT.word_counts, ext_term(LEFT,RIGHT));
  SHARED nominal_list := TABLE(t_list,
                              {model, nominal, occurs:=SUM(GROUP,freq)},
                              model, nominal, MERGE);
  t_tab := TABLE(nominal_list,
                 {model, nominals:=COUNT(GROUP), words:=SUM(GROUP,occurs),
                  UNSIGNED8 low_nominal:=MIN(GROUP,nominal),
                  UNSIGNED8 high_nominal:=MAX(GROUP,nominal)},
                 model, MERGE);
  SHARED t_tab_sorted := SORT(DISTRIBUTE(t_tab, model), model, LOCAL);
  d_tab := TABLE(assigned,
                 {model, dc:=COUNT(GROUP),
                  min_doc_words:=MIN(GROUP, SUM(word_counts, v)),
                  max_doc_words:=MAX(GROUP, SUM(word_counts, v)),
                  ave_doc_words:=AVE(GROUP, SUM(word_counts, v))},
                 model, FEW, UNSORTED);
  SHARED d_tab_sorted := SORT(DISTRIBUTE(d_tab, model), model, LOCAL);
  Stats_Rec cvt(d_tab_sorted ds, t_tab_sorted ts) := TRANSFORM
    SELF.model := ds.model;
    SELF.docs := ds.dc;
    SELF.unique_words := ts.nominals;
    SELF.doc_min_words := ds.min_doc_words;
    SELF.doc_max_words := ds.max_doc_words;
    SELF.doc_ave_words := ds.ave_doc_words;
    SELF.words := ts.words;
    SELF.low_nominal := ts.low_nominal;
    SELF.high_nominal := ts.high_nominal;
  END;
  rslt := COMBINE(d_tab_sorted, t_tab_sorted, cvt(LEFT,RIGHT), LOCAL);
  /**
   * Document statistics for each model.  Used by the initial model
   * generator and by several of the initiol estimate generators.
   * @return          the number of documents, unique words, and total word
   *                  occurrences.
   */
  EXPORT DATASET(Types.Model_Collection_Stats) Stats := rslt;
  // Ordinal list creation
  Ordinal_Rec := RECORD
    Types.t_model_id model;
    Types.t_nominal nominal;
    Types.t_ordinal ordinal;
    UNSIGNED8 freq;
    UNSIGNED2 node;
  END;
  Ordinal_Rec cvt2ol(nominal_list nl, UNSIGNED4 c) := TRANSFORM
    SELF.ordinal := c;
    SELF.node := ThorLib.node();
    SELF.freq := nl.occurs;
    SELF := nl;
  END;
  by_freq_list := SORT(nominal_list, model, -occurs, nominal);
  local_list := PROJECT(by_freq_list, cvt2ol(LEFT,COUNTER), LOCAL);
  node_rec := RECORD
    local_list.model;
    local_list.node;
    UNSIGNED4 l_count := COUNT(GROUP);
    INTEGER4 this_adj := 0;
    UNSIGNED4 last_ord := 0;
    UNSIGNED4 l_count_adj := 0;
  END;
  nc_raw := TABLE(local_list, node_rec, model, node, FEW, UNSORTED, LOCAL);
  node_counts := SORT(nc_raw, model, LOCAL);
  node_rec prop_adj(node_rec prev, node_rec curr) := TRANSFORM
    same_model := prev.model=curr.model;
    same_node := prev.node=curr.node;
    SELF.l_count_adj := IF(same_node, prev.l_count_adj, 0) + curr.l_count;
    SELF.this_adj := IF(same_node, -prev.l_count_adj, 0);
    SELF.last_ord := IF(same_model, prev.last_ord + prev.l_count, 0);
    SELF := curr;
  END;
  adjustments := ITERATE(node_counts, prop_adj(LEFT, RIGHT));
  Ordinal_Rec adj_ord(Ordinal_rec o, node_rec nr) := TRANSFORM
    SELF.ordinal := o.ordinal + nr.last_ord + nr.this_adj;
    SELF := o;
  END;
  adj_list := JOIN(local_list, adjustments,
                   LEFT.model=RIGHT.model AND LEFT.node=RIGHT.node,
                   adj_ord(LEFT, RIGHT), LOOKUP);
  /**
   * Nominal Ordinal map by Model.
   *@return the map
   */
  rslt := PROJECT(adj_list, Types.Model_Nom_Ord_Map);
  EXPORT Nominal_Ordinal_Map := rslt;
  /**
   * Ordinalized term dictionary by model.
   * @param   dict the the nominal dictionary mapping to text
   * @return  the ordinal dictionary for each model
   */
  EXPORT DATASET(Types.Model_Term_Dict_Ord)
         Ordinalized_Dict(DATASET(Types.Term_Dict) dict) := FUNCTION
    Types.Model_Term_Dict_Ord j0(Types.Model_Nom_Ord_Map no_map,
                                 Types.Term_Dict dict) := TRANSFORM
      SELF := no_map;
      SELF := dict;
    END;
    rslt := JOIN(Nominal_Ordinal_Map, dict,
                 LEFT.nominal=RIGHT.nominal,
                 j0(LEFT, RIGHT), LOOKUP, MANY);
    RETURN rslt;
  END;
END;