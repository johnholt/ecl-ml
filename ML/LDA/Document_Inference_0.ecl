IMPORT $ AS LDA;
IMPORT $.Types AS Types;
IMPORT Std.System.ThorLib;
Scored := Types.Document_Scored;
/**
 * Direct scoring of unseen documents with model and parameters.
 *@param model_estimates the model
 *@param docs the documents
 *@return scored documents
 */
EXPORT DATASET(LDA.Types.Document_Scored)
   Document_Inference_0(DATASET(LDA.Types.Model_Topic) model_estimates,
                        DATASET(LDA.Types.Doc_Mapped) docs) := FUNCTION
  // Copy weights to each node
  Ex_Mod := RECORD(Types.Model_Topic)
    UNSIGNED2 node;
  END;
  Ex_Mod repl(Types.Model_Topic mt, UNSIGNED8 c) := TRANSFORM
    SELF.node := c-1;
    SELF := mt;
  END;
  replicated := NORMALIZE(model_estimates, ThorLib.nodes(),
                          repl(LEFT, COUNTER));
  local_mod_est := DISTRIBUTE(replicated, node);
  // unload weights
  Weight := RECORD
    Types.t_model_id model;
    Types.t_nominal nominal;
    Types.t_topic topic;
    REAL8 weight;
  END;
  Weight getW(Types.Model_Topic m, Types.TermValue t):=TRANSFORM
    SELF.weight := t.v;
    SELF.nominal := t.nominal;
    SELF := m;
  END;
  wghts := NORMALIZE(local_mod_est, LEFT.weights, getW(LEFT, RIGHT));
  // explode docs
  Work_Doc := RECORD(Types.Document)
    Types.t_model_id model;
  END;
  Mod_Rec := {Types.t_model_id model};
  Work_Doc setModel(Types.Doc_Mapped d, Mod_Rec m) := TRANSFORM
    SELF.model := m.model;
    SELF := d;
  END;
  x_docs := NORMALIZE(docs, DATASET(LEFT.models, Mod_Rec),
                      setModel(LEFT, RIGHT));
  // unload doc terms
  Doc_Term := RECORD
    Types.t_model_id model;
    Types.t_record_id rid;
    Types.t_nominal nominal;
    UNSIGNED4 freq;
  END;
  Doc_Term getT(Work_Doc d, Types.TermFreq t) := TRANSFORM
    SELF.freq := t.v;
    SELF.nominal := t.nominal;
    SELF := d;
  END;
  trms := NORMALIZE(x_docs, LEFT.word_counts, getT(LEFT, RIGHT));
  // score terms
  Term_Score := RECORD
    Types.t_model_id model;
    Types.t_record_id rid;
    Types.t_topic topic;
    REAL8 v;
  END;
  Term_Score weight_term(Doc_Term dt, Weight w) := TRANSFORM
    SELF.v := dt.freq*w.weight;
    SELF.topic := w.topic;
    SELF := dt;
  END;
  weighed := JOIN(trms, wghts,
                  LEFT.model=RIGHT.model AND LEFT.nominal=RIGHT.nominal,
                  weight_term(LEFT, RIGHT), LEFT OUTER, LOCAL);
  // Group and sum by topic
  srt_weighted := SORT(weighed, model, rid, topic, LOCAL);
  grp_weighted := GROUP(srt_weighted, model, rid, topic, LOCAL);
  Term_Score sum_tv(Term_Score t, DATASET(Term_Score) r):=TRANSFORM
    SELF.v := SUM(r, v);
    SELF := t;
  END;
  d_t_scores := ROLLUP(grp_weighted, GROUP, sum_tv(LEFT, ROWS(LEFT)));
  // roll up into Doc Scored
  Scored roll_tv(Term_Score s, DATASET(Term_Score) r):=TRANSFORM
    SELF.likelihood := 0; // unknown
    SELF.topics := PROJECT(r(topic<>0), Types.Topic_Value);
    SELF := s;
  END;
  grp_dt := GROUP(d_t_scores, model, rid, LOCAL);
  rslt := ROLLUP(grp_dt, GROUP, roll_tv(LEFT, ROWS(LEFT)));
  RETURN rslt;
END;