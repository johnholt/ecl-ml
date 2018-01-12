//Prepare the documents and collection information for sampling.
//The documents are a list of nominals for the terms in the document.  The
// nominal value occurs in the list as many times as the word occurred in
// the document.
//Each word occurrence is assigned a topic based upon the initial term-topic
// weights.
//The term nominals are ordered by descending frequency and assigned ordinal
// values.
//The global term-topic information is organized into two sections.  The highest
// frequency terms (ordinal positions up to the split value) counts are held in a
// dense matrix by topic and term ordinal.  The preponderance of terms are lower
// frequency terms and are held in a sparse matrix which is compressed.
//The collection information is added to the document record set by assigning
// a rid value of MAX_U4 and by setting the isDoc flag to FALSE.
IMPORT $ AS LDA;
IMPORT $.Types AS Types;
IMPORT Std.System.ThorLib;
Model_Topic := Types.Model_Topic;
TermValue := Types.TermValue;
TermFreq := Types.TermFreq;
Topic_Value := Types.Topic_Value;
Mod_N_O_Map := Types.Model_Nom_Ord_Map;
Doc_Assigned := Types.Doc_Assigned_MC;
Coll_Stats := Types.Model_Collection_Stats;
Mod_Parms := Types.MC_Model_Parameters;
MC_Term_Topic_Map := Types.MC_Term_Topic_Map;
Collection_MC := Types.Collection_MC;
emp := DATASET([], Model_Topic);
MAX_U4 := 4294967295;
REAL8 denominator := 1.0/((REAL8)(MAX_U4));
MAX_DENSE_SIZE := 10000000;


EXPORT DATASET(Types.Doc_Assigned_MC)
       prep_mc_docs(DATASET(Types.MC_Model_Parameters) parameters,
                    DATASET(Types.Model_Topic) initial_estimate=emp,
                    DATASET(Types.Model_Collection_Stats) stats,
                    DATASET(Types.Model_Nom_Ord_Map) mno_map,
                    DATASET(Types.Doc_Mapped) docs) := FUNCTION
  //Extend nominal ordinal map with initial estimated log Beta
  //First invert to have nominal records with topic array
  TT_Work := RECORD
    Types.t_model_id model;
    Types.t_topic topic;
    Types.t_nominal nominal;
    REAL8 v;
  END;
  TT_Work f_tt(Model_Topic m, TermValue tv):=TRANSFORM
    SELF := tv;
    SELF := m;
  END;
  f_est := NORMALIZE(initial_estimate, LEFT.weights, f_tt(LEFT,RIGHT));
  grp_est := GROUP(f_est, model, nominal, ALL);
  TT_set := RECORD
    Types.t_model_id model;
    Types.t_nominal nominal;
    Types.Topic_Value_Dataset logBetas;
  END;
  TT_set r_tt(TT_Work p, DATASET(TT_Work) w) := TRANSFORM
    SELF.logBetas := SORT(PROJECT(w, Topic_Value), topic);
    SELF := p;
  END;
  model_nom_logbetas := ROLLUP(grp_est, GROUP, r_tt(LEFT,ROWS(LEFT)));
  // add beta coefficients to nominal-ordinal map
  Work_Map := RECORD(Types.Model_Nom_Ord_Map)
    BOOLEAN hasEst;
    Types.Topic_Value_Dataset logBetas;
  END;
  Work_Map add_betas(Mod_N_O_Map mm, TT_set tt) := TRANSFORM
    SELF.hasEst := tt.nominal<>0;
    SELF.logBetas := tt.logBetas;
    SELF := mm;
  END;
  w_betas_map := JOIN(mno_map, model_nom_logbetas,
                       LEFT.model=RIGHT.model
                       AND LEFT.nominal=RIGHT.nominal,
                       add_betas(LEFT, RIGHT), LEFT OUTER, LOOKUP);
  // add collection information to nominal-ordinal map
  Collection_Map := RECORD(Work_Map)
    UNSIGNED4 uniq_words;
  END;
  Collection_Map add_coll(Work_Map wm, Coll_Stats s):=TRANSFORM
    SELF.uniq_words := s.unique_words;
    SELF := wm;
  END;
  w_coll_map := JOIN(w_betas_map, stats,
                    LEFT.model=RIGHT.model,
                    add_coll(LEFT, RIGHT), LOOKUP);
  // add model parameter information to nominal-ordinal map
  Parm_Map := RECORD(Collection_Map)
    UNSIGNED4 num_topics;
  END;
  Parm_Map add_parm(Collection_Map cm, Mod_Parms p) := TRANSFORM
    SELF.num_topics := p.num_topics;
    SELF := cm;
  END;
  w_parms_map := JOIN(w_coll_map, parameters,
                      LEFT.model=RIGHT.model,
                      add_parm(LEFT, RIGHT), LOOKUP);
  //Determine split for dense/sparse
  dense_recs := w_parms_map(freq > num_topics/1.5);
  dense_tab := TABLE(dense_recs, {model, split:=MAX(GROUP, ordinal)},
                     model, FEW, UNSORTED);
  // use natural split to determine split point
  Split_Map := RECORD(Parm_Map)
    Types.t_ordinal split;
  END;
  Split_Map add_split(Parm_Map pm, RECORDOF(dense_tab) dt) := TRANSFORM
    max_size := pm.num_topics*pm.uniq_words;
    split:= IF(dt.split=0 OR dt.split*pm.num_topics>MAX_DENSE_SIZE,
               MAX_DENSE_SIZE DIV pm.num_topics, dt.split);
    SELF.split := IF(max_size<=MAX_DENSE_SIZE, pm.uniq_words, split);
    SELF := pm;
  END;
  w_split_map := JOIN(w_parms_map, dense_tab, LEFT.model=RIGHT.model,
                      add_split(LEFT, RIGHT), LEFT OUTER, LOOKUP);
  //Normalize model-doc to model-doc-term records
  Work_Doc := RECORD(Types.Doc_Mapped)
    Types.t_model_id model;
  END;
  Work_Doc norm_doc(Types.Doc_Mapped doc, UNSIGNED c) := TRANSFORM
    SELF.model := doc.models[c];
    SELF := doc;
  END;
  docsx := NORMALIZE(docs, COUNT(LEFT.models),
                     norm_doc(LEFT, COUNTER));
  Nom_Rec := RECORD
    Types.t_nominal nominal;
  END;
  Work_DT := RECORD
    Types.t_model_id model;
    Types.t_record_id rid;
    Types.t_nominal nominal;
  END;
  norm_wc(DATASET(TermFreq) w)
      := NORMALIZE(w, LEFT.v, TRANSFORM(Nom_Rec, SELF:=LEFT));
  Work_DT norm_doc_term(Work_Doc doc, Nom_Rec n) := TRANSFORM
    SELF := n;
    SELF := doc;
  END;
  doc_terms := NORMALIZE(docsx, norm_wc(LEFT.word_counts),
                         norm_doc_term(LEFT, RIGHT));
  // join against map, assign initial topics
  Work_DTO := RECORD
    Types.t_model_id model;
    Types.t_record_id rid;
    Types.t_ordinal ordinal;
    Types.t_topic topic;
    UNSIGNED4 num_topics;
    UNSIGNED4 uniq_words;
    Types.t_ordinal split;
  END;
  Work_DTO add_map(Work_DT doc, Split_Map s) := TRANSFORM
    SELF.ordinal := s.ordinal;
    SELF.num_topics := s.num_topics;
    SELF.uniq_words := s.uniq_words;
    SELF.split := s.split;
    SELF.topic := MIN(((RANDOM()*denominator) * (s.num_topics))+1,
                      s.num_topics); // need option to use betas
    SELF := doc;
  END;
  doc_ord := JOIN(doc_terms, w_split_map,
                  LEFT.model=RIGHT.model AND LEFT.nominal=RIGHT.nominal,
                  add_map(LEFT, RIGHT), LOOKUP);
  //base documents
  grp_doc_ord := GROUP(doc_ord, model, rid, LOCAL);
  Doc_Assigned rollBase(Work_DTO b, DATASET(Work_DTO) rws) := TRANSFORM
    z := SORT(PROJECT(rws, Types.MC_Term_Topic), ordinal);
    nd := LDA.init_doc_nd(z, b.num_topics, COUNT(z));
    SELF.model := b.model;
    SELF.rid := b.rid;
    SELF.split := b.split;
    SELF.isDoc := TRUE;
    SELF.doc_words := COUNT(z);
    SELF.doc_topics := COUNT(nd(freq>0));
    SELF.num_topics := b.num_topics;
    SELF.uniq_words := b.uniq_words;
    SELF.z := z;
    SELF.nd := nd;
    SELF := [];
  END;
  w_terms_docs := ROLLUP(grp_doc_ord, GROUP, rollBase(LEFT, ROWS(LEFT)));
  //pick up model and collection info
  Doc_Assigned get_cstat(Doc_Assigned d, Coll_Stats s) := TRANSFORM
    SELF.uniq_words := s.unique_words;
    SELF := d;
  END;
  w_cstat_docs := JOIN(w_terms_docs, stats, LEFT.model=RIGHT.model,
                       get_cstat(LEFT, RIGHT), LOOKUP);
  Doc_Assigned get_mdl(Doc_Assigned d, Mod_Parms p) := TRANSFORM
    SELF.alpha := p.initial_alpha;
    SELF.beta := p.initial_beta;
    SELF := d;
  END;
  base_docs := JOIN(w_cstat_docs, parameters, LEFT.model=RIGHT.model,
                    get_mdl(LEFT, RIGHT), LOOKUP);
  //gather general info
  model_data := TABLE(doc_ord, {model, num_topics, uniq_words, split},
                      model, num_topics, uniq_words, split, FEW, UNSORTED);
  Collection_MC cvt2MC(RECORDOF(model_data) md) := TRANSFORM
    SELF.model := md.model;
    SELF.num_topics := md.num_topics;
    SELF.uniq_words := md.uniq_words;
    SELF.split := md.split;
    SELF := [];
  END;
  model_collection_empty := PROJECT(model_data, cvt2MC(LEFT));
  //Gather collection level nwsum
  TC_Rec := RECORD
    doc_ord.model;
    doc_ord.topic;
    UNSIGNED4 freq:=COUNT(GROUP);
    doc_ord.num_topics;
  END;
  topic_counts := TABLE(doc_ord, TC_Rec, model, topic, num_topics,
                        FEW, UNSORTED);
  Work_nwsum := RECORD
    Types.t_model_id model;
    EMBEDDED DATASET(Types.MC_Freq) nwsum;
  END;
  Work_nwsum roll_nwsum(TC_Rec p, DATASET(TC_Rec) c) := TRANSFORM
    tc := PROJECT(c, Types.MC_Topic_Freq);
    SELF.nwsum := LDA.init_nwsum(tc, p.num_topics);
    SELF.model := p.model;
  END;
  grp_tc := GROUP(Topic_counts, model, ALL);
  model_nwsum := ROLLUP(grp_tc, GROUP, roll_nwsum(LEFT, ROWS(LEFT)));
  Collection_MC add_nwsum(Collection_MC c, Work_nwsum w) := TRANSFORM
    SELF.nwsum := w.nwsum;
    SELF := c;
  END;
  model_collection_0 := JOIN(model_collection_empty, model_nwsum,
                             LEFT.model=RIGHT.model,
                             add_nwsum(LEFT, RIGHT));
  // Gather collection level for nw
  Work_to := RECORD
    doc_ord.model;
    doc_ord.topic;
    doc_ord.ordinal;
    doc_ord.split;
    doc_ord.uniq_words;
    doc_ord.num_topics;
    UNSIGNED4 freq := COUNT(GROUP);
  END;
  topic_ord := TABLE(doc_ord, Work_to, model, ordinal, topic,
                     split, num_topics, uniq_words, MERGE);
  dense_to := GROUP(topic_ord(ordinal<=split), model, ALL);
  Work_nw := RECORD
    Types.t_model_id model;
    EMBEDDED DATASET(Types.MC_Freq) nw;
  END;
  Work_nw roll_nw(Work_to p, DATASET(Work_to) c) := TRANSFORM
    nw_raw := PROJECT(c, Types.MC_Term_Topic_Freq);
    SELF.nw := LDA.init_nw(nw_raw, p.split, p.num_topics);
    SELF.model := p.model;
  END;
  model_nw := ROLLUP(dense_to, GROUP, roll_nw(LEFT, ROWS(LEFT)));
  // Build part of Collection MC with nwsum and dense nw
  Collection_MC nwsum_nw(Collection_MC c, Work_nw w) := TRANSFORM
    SELF.nw := w.nw;
    SELF := c;
  END;
  model_collection_1 := JOIN(model_collection_0, model_nw,
                             LEFT.model=RIGHT.model,
                             nwsum_nw(LEFT, RIGHT));
  // Build nwmap/nwfreq
  Work_to_s := RECORD
    Types.t_model_id model;
    Types.t_ordinal ordinal;
    Types.t_topic topic;
    Types.t_ordinal split;
    UNSIGNED4 model_num_topics;
    UNSIGNED4 uniq_words;
    UNSIGNED4 freq;
    UNSIGNED4 pos;  // 1 based
  END;
  Work_to_s cvt_to_s(Work_to ttf) := TRANSFORM
    SELF.pos := 0;
    SELF.model_num_topics := ttf.num_topics;
    SELF := ttf;
  END;
  sparse_to_s := PROJECT(topic_ord(ordinal>split), cvt_to_s(LEFT));
  grp_sparse_to_s := GROUP(sparse_to_s, model, ALL);
  seq_sparse_to_s := SORT(grp_sparse_to_s, ordinal, topic);
  Work_to_s mark_pos(Work_to_s prev, Work_to_s curr) := TRANSFORM
    SELF.pos := prev.pos + 1;
    SELF := curr;
  END;
  pos_sparse_to_s := ITERATE(seq_sparse_to_s, mark_pos(LEFT, RIGHT));
  W_nwmap_raw := RECORD
    pos_sparse_to_s.model;
    pos_sparse_to_s.ordinal;
    UNSIGNED4 num_topics := COUNT(GROUP);
    UNSIGNED4 list_pos := MIN(GROUP, pos_sparse_to_s.pos) -1;
  END;
  nw_map_raw := TABLE(UNGROUP(pos_sparse_to_s), W_nwmap_raw,
                      model, ordinal, FEW, UNSORTED);
  nw_map_grp := GROUP(nw_map_raw, model, ALL);
  W_nwmap := RECORD
    Types.t_model_id model;
    EMBEDDED DATASET(Types.MC_Term_Topic_Map) ttm;
  END;
  W_nwmap r_nwmap(W_nwmap_raw p, DATASET(W_nwmap_raw) rws) := TRANSFORM
    SELF.model := p.model;
    SELF.ttm := PROJECT(SORT(rws, ordinal), MC_Term_Topic_Map);
  END;
  model_nwmap := ROLLUP(nw_map_grp, GROUP, r_nwmap(LEFT, ROWS(LEFT)));
  Collection_MC add_nwmap(Collection_MC p, W_nwmap m):=TRANSFORM
    SELF.nwmap := m.ttm;
    SELF := p;
  END;
  model_collection_2 := JOIN(model_collection_1, model_nwmap,
                             LEFT.model=RIGHT.model,
                             add_nwmap(LEFT, RIGHT), LEFT OUTER);
  W_nwfreq := RECORD
    Types.t_model_id model;
    EMBEDDED DATASET(Types.MC_Topic_Freq) tf;
  END;
  W_nwfreq r_nwfreq(Work_to_s p, DATASET(Work_to_s) rws):=TRANSFORM
    SELF.model := p.model;
    SELF.tf := PROJECT(SORT(rws, pos), Types.MC_Topic_Freq);
  END;
  model_nwfreq := ROLLUP(pos_sparse_to_s, GROUP,
                         r_nwfreq(LEFT, ROWS(LEFT)));
  Collection_MC add_nwfreq(Collection_MC p, W_nwfreq f):=TRANSFORM
    SELF.nwfreq := f.tf;
    SELF := p;
  END;
  model_collection_3 := JOIN(model_collection_2, model_nwfreq,
                             LEFT.model=RIGHT.model,
                             add_nwfreq(LEFT, RIGHT), LEFT OUTER);
  // Now extend to nodes
  Work_Collection := RECORD(Collection_MC)
    UNSIGNED2 node;
  END;
  Work_Collection add_node(Collection_MC p, UNSIGNED c):=TRANSFORM
    SELF.node := c-1;
    SELF := p;
  END;
  model_collection_r := NORMALIZE(model_collection_3,
                                  ThorLib.nodes(),
                                  add_node(LEFT, COUNTER));
  model_collection := DISTRIBUTE(model_collection_r, node);
  // add collection into documents
  Doc_Assigned cvt_coll(Types.Collection_MC col) := TRANSFORM
    SELF.model := col.model;
    SELF.nwsum := col.nwsum;
    SELF.nw := col.nw;
    SELF.nwmap := col.nwmap;
    SELF.nwfreq := col.nwfreq;
    SELF.split := col.split;
    SELF.uniq_words := col.uniq_words;
    SELF.isDoc := FALSE;
    SELF.num_topics := col.num_topics;
    SELF.rid := MAX_U4;
    SELF := [];
  END;
  mc_as_doc := PROJECT(model_collection, cvt_coll(LEFT));
  mrg_docs := SORT(mc_as_doc + base_docs, model, rid, -isDoc, LOCAL);
  Doc_Assigned mark_1st(Doc_Assigned prev, Doc_Assigned curr):=TRANSFORM
    SELF.isFirst := prev.model<>curr.model;
    SELF := curr;
  END;
  rslt_docs := ITERATE(mrg_docs, mark_1st(LEFT, RIGHT), LOCAL);
  RETURN rslt_docs;
END;
